defmodule ArchitectureGenerator.Uploads.Upload do
  use Ecto.Schema
  import Ecto.Changeset

  schema "uploads" do
    field :filename, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :s3_key, :string
    field :s3_bucket, :string
    field :current_version, :integer, default: 1
    field :uploaded_by, :string

    belongs_to :project, ArchitectureGenerator.Projects.Project
    has_many :versions, ArchitectureGenerator.Uploads.UploadVersion

    timestamps()
  end

  @doc """
  Changeset for creating a new upload
  """
  def create_changeset(upload, attrs) do
    upload
    |> cast(attrs, [:filename, :content_type, :size_bytes, :s3_key, :s3_bucket, :project_id, :uploaded_by])
    |> validate_required([:filename, :s3_key, :s3_bucket])
    |> validate_length(:filename, min: 1, max: 255)
    |> unique_constraint([:s3_key, :s3_bucket])
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Changeset for updating current version number
  """
  def update_version_changeset(upload, version_number) do
    upload
    |> cast(%{}, [])
    |> put_change(:current_version, version_number)
  end

  @doc """
  Generate a unique S3 key for an upload
  """
  def generate_s3_key(project_id, filename) do
    timestamp = DateTime.utc_now() |> DateTime.to_unix()
    ext = Path.extname(filename)
    base = Path.basename(filename, ext)
    sanitized_base = sanitize_filename(base)

    "projects/#{project_id}/#{timestamp}_#{sanitized_base}#{ext}"
  end

  defp sanitize_filename(filename) do
    filename
    |> String.replace(~r/[^a-zA-Z0-9_-]/, "_")
    |> String.slice(0..100)
  end
end
