defmodule ArchitectureGenerator.Uploads do
  @moduledoc """
  The Uploads context handles file uploads to S3 with versioning support.
  """

  import Ecto.Query, warn: false
  require Logger

  alias ArchitectureGenerator.Repo
  alias ArchitectureGenerator.Uploads.{Upload, UploadVersion}
  alias ArchitectureGenerator.{DocumentParser, LLMService}
  alias ExAws.S3

  # Removed compile-time module attributes - now using runtime config
  # This allows configuration to be changed without recompiling
  defp get_bucket, do: Application.get_env(:architecture_generator, :uploads_bucket)
  defp get_storage_type, do: Application.get_env(:architecture_generator, :file_storage, :s3)
  defp get_uploads_dir,
    do: Application.get_env(:architecture_generator, :uploads_dir, "priv/static/uploads")

  @doc """
  Returns the list of uploads.

  ## Examples

      iex> list_uploads()
      [%Upload{}, ...]

  """
  def list_uploads do
    Upload
    |> preload([:project, :versions])
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of uploads for a specific project.
  """
  def list_uploads_by_project(project_id) do
    Upload
    |> where([u], u.project_id == ^project_id)
    |> preload(:versions)
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single upload.

  Raises `Ecto.NoResultsError` if the Upload does not exist.

  ## Examples

      iex> get_upload!(123)
      %Upload{}

      iex> get_upload!(456)
      ** (Ecto.NoResultsError)

  """
  def get_upload!(id) do
    # Repo.get!/1 already raises Ecto.NoResultsError if not found,
    # so we don't need to handle nil case
    Upload
    |> Repo.get!(id)
    |> Repo.preload([
      :project,
      versions: from(v in UploadVersion, order_by: [desc: v.version_number])
    ])
  end

  @doc """
  Creates an upload and stores the file in S3.
  Also attempts to parse the file and extract text content.

  Returns {:ok, upload, parsed_content} or {:ok, upload, nil} if parsing fails.

  ## Examples

      iex> create_upload(%{field: value}, file_path)
      {:ok, %Upload{}, "Extracted text content"}

      iex> create_upload(%{field: bad_value}, file_path)
      {:error, %Ecto.Changeset{}}

  """
  def create_upload(attrs, file_path) do
    # Check file size first to avoid loading huge files into memory
    max_size = 100 * 1024 * 1024  # 100 MB limit

    with {:ok, %{size: file_size}} <- File.stat(file_path),
         :ok <- validate_upload_size(file_size, max_size),
         {:ok, file_binary} <- File.read(file_path),
         s3_key <-
           Upload.generate_s3_key(
             attrs[:project_id] || attrs["project_id"],
             attrs[:filename] || attrs["filename"]
           ),
         {:ok, _} <-
           upload_to_storage(s3_key, file_binary, attrs[:content_type] || attrs["content_type"]) do
      # Get processing mode from attrs
      processing_mode = attrs[:processing_mode] || attrs["processing_mode"] || "parse_only"
      llm_provider = attrs[:llm_provider] || attrs["llm_provider"] || "openai"

      # Process the file based on mode
      processed_content =
        case processing_mode do
          "parse_only" ->
            # Just parse the document
            case DocumentParser.parse_file(file_path) do
              {:ok, content} -> content
              {:error, _reason} -> nil
            end

          "llm_parsed" ->
            # Parse first, then enhance with LLM
            case DocumentParser.parse_file(file_path) do
              {:ok, parsed_text} ->
                case LLMService.enhance_parsed_text(parsed_text, provider: llm_provider) do
                  {:ok, enhanced_content} ->
                    enhanced_content

                  {:error, reason} ->
                    Logger.warning(
                      "LLM enhancement failed for file #{attrs[:filename]}: #{inspect(reason)}. Falling back to parsed text."
                    )

                    parsed_text
                end

              {:error, reason} ->
                Logger.error(
                  "Document parsing failed for file #{attrs[:filename]}: #{inspect(reason)}"
                )

                nil
            end

          "llm_raw" ->
            # Send raw file to LLM
            filename = attrs[:filename] || attrs["filename"]

            case LLMService.convert_document_to_brd(file_binary, filename, provider: llm_provider) do
              {:ok, brd_content} ->
                brd_content

              {:error, reason} ->
                Logger.error(
                  "LLM conversion failed for file #{filename}: #{inspect(reason)}"
                )

                nil
            end

          _ ->
            # Default to parse_only
            case DocumentParser.parse_file(file_path) do
              {:ok, content} -> content
              {:error, _reason} -> nil
            end
        end

      # Create the upload record
      upload_attrs =
        Map.merge(attrs, %{
          s3_key: s3_key,
          s3_bucket: get_bucket(),
          uploaded_by: attrs[:uploaded_by] || attrs["uploaded_by"]
        })

      %Upload{}
      |> Upload.create_changeset(upload_attrs)
      |> Repo.insert()
      |> case do
        {:ok, upload} ->
          # Create initial version
          create_version(upload, %{
            version_number: 1,
            filename: upload.filename,
            content_type: upload.content_type,
            size_bytes: upload.size_bytes,
            s3_key: upload.s3_key,
            s3_bucket: upload.s3_bucket,
            uploaded_by: attrs[:uploaded_by] || attrs["uploaded_by"]
          })

          {:ok, Repo.preload(upload, :versions), processed_content}

        {:error, changeset} ->
          # Cleanup storage if DB insert fails
          delete_from_storage(s3_key)
          {:error, changeset}
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Updates an upload by creating a new version.
  Also attempts to parse the new file and extract text content.

  Returns {:ok, upload, parsed_content} or {:ok, upload, nil} if parsing fails.
  """
  def update_upload(upload, file_path, attrs \\ %{}) do
    # Check file size first to avoid loading huge files into memory
    max_size = 100 * 1024 * 1024  # 100 MB limit

    with {:ok, %{size: file_size}} <- File.stat(file_path),
         :ok <- validate_upload_size(file_size, max_size),
         {:ok, file_binary} <- File.read(file_path),
         next_version <- upload.current_version + 1,
         s3_key <-
           Upload.generate_s3_key(
             upload.project_id,
             attrs[:filename] || attrs["filename"] || upload.filename
           ),
         {:ok, _} <-
           upload_to_storage(
             s3_key,
             file_binary,
             attrs[:content_type] || attrs["content_type"] || upload.content_type
           ) do
      # Try to parse the document and extract text
      parsed_content =
        case DocumentParser.parse_file(file_path) do
          {:ok, content} -> content
          {:error, _reason} -> nil
        end

      # Create new version
      version_attrs = %{
        upload_id: upload.id,
        version_number: next_version,
        filename: attrs[:filename] || attrs["filename"] || upload.filename,
        content_type: attrs[:content_type] || attrs["content_type"] || upload.content_type,
        size_bytes: attrs[:size_bytes] || attrs["size_bytes"] || byte_size(file_binary),
        s3_key: s3_key,
        s3_bucket: get_bucket(),
        uploaded_by: attrs[:uploaded_by] || attrs["uploaded_by"]
      }

      case create_version(upload, version_attrs) do
        {:ok, _version} ->
          # Update upload's current version
          upload
          |> Upload.update_version_changeset(next_version)
          |> Repo.update()
          |> case do
            {:ok, updated_upload} ->
              {:ok, Repo.preload(updated_upload, :versions, force: true), parsed_content}

            error ->
              error
          end

        error ->
          delete_from_storage(s3_key)
          error
      end
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Deletes an upload and all its versions from S3 and database.
  """
  def delete_upload(%Upload{} = upload) do
    # Delete all versions from storage
    upload = Repo.preload(upload, :versions)

    Enum.each(upload.versions, fn version ->
      delete_from_storage(version.s3_key)
    end)

    # Delete current file from storage
    delete_from_storage(upload.s3_key)

    # Delete from database (cascade will handle versions)
    Repo.delete(upload)
  end

  defp create_version(upload, attrs) do
    %UploadVersion{}
    |> UploadVersion.create_changeset(Map.put(attrs, :upload_id, upload.id))
    |> Repo.insert()
  end

  defp validate_upload_size(size, max_size) when size > max_size do
    Logger.error("File size #{size} bytes exceeds maximum allowed size of #{max_size} bytes")
    {:error, {:file_too_large, "File size exceeds #{max_size} bytes limit"}}
  end

  defp validate_upload_size(_size, _max_size), do: :ok

  defp upload_to_storage(key, binary, content_type) do
    case get_storage_type() do
      :local ->
        upload_to_local(key, binary)

      :s3 ->
        upload_to_s3(key, binary, content_type)
    end
  end

  defp delete_from_storage(key) do
    case get_storage_type() do
      :local ->
        delete_from_local(key)

      :s3 ->
        delete_from_s3(key)
    end
  end

  # Local file storage operations
  defp upload_to_local(key, binary) do
    file_path = Path.join(get_uploads_dir(), key)
    file_dir = Path.dirname(file_path)

    with :ok <- File.mkdir_p(file_dir),
         :ok <- File.write(file_path, binary) do
      {:ok, :local}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  defp delete_from_local(key) do
    file_path = Path.join(get_uploads_dir(), key)

    case File.rm(file_path) do
      :ok -> {:ok, :local}
      {:error, :enoent} -> {:ok, :local}
      {:error, reason} -> {:error, reason}
    end
  end

  # S3 operations
  defp upload_to_s3(key, binary, content_type) do
    S3.put_object(get_bucket(), key, binary, content_type: content_type || "application/octet-stream")
    |> ExAws.request()
  end

  defp delete_from_s3(key) do
    S3.delete_object(get_bucket(), key)
    |> ExAws.request()
  end

  @doc """
  Gets a presigned URL for downloading a file from S3.
  """
  def get_download_url(upload) do
    case get_storage_type() do
      :local ->
        # Return a path to the static file
        "/uploads/#{upload.s3_key}"

      :s3 ->
        {:ok, url} =
          S3.presigned_url(ExAws.Config.new(:s3), :get, get_bucket(), upload.s3_key, expires_in: 3600)

        url
    end
  end

  @doc """
  Gets a presigned URL for a specific version.
  """
  def get_version_download_url(version) do
    case get_storage_type() do
      :local ->
        # Return a path to the static file
        "/uploads/#{version.s3_key}"

      :s3 ->
        {:ok, url} =
          S3.presigned_url(ExAws.Config.new(:s3), :get, get_bucket(), version.s3_key, expires_in: 3600)

        url
    end
  end
end
