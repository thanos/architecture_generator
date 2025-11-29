defmodule ArchitectureGenerator.DocumentParser do
  @moduledoc """
  Parses various document formats and extracts text content.

  Supported formats:
  - PDF (.pdf)
  - Microsoft Word (.docx, .doc)
  - Markdown (.md)
  - Plain text (.txt)
  """

  require Logger

  @doc """
  Parses a file and extracts its text content.

  Returns {:ok, content} or {:error, reason}

  ## Examples

      iex> parse_file("/path/to/document.pdf")
      {:ok, "Extracted text content..."}
      
      iex> parse_file("/path/to/invalid.xyz")
      {:error, :unsupported_format}
  """
  def parse_file(file_path) do
    case Path.extname(file_path) |> String.downcase() do
      ".pdf" -> parse_pdf(file_path)
      ".docx" -> parse_docx(file_path)
      ".doc" -> parse_doc(file_path)
      ".md" -> parse_markdown(file_path)
      ".txt" -> parse_text(file_path)
      ext -> {:error, {:unsupported_format, ext}}
    end
  end

  @doc """
  Parses a PDF file and extracts text content.
  """
  def parse_pdf(file_path) do
    Logger.info("Parsing PDF file: #{file_path}")

    case Pdf.extract(file_path) do
      {:ok, content} ->
        cleaned_content = clean_text(content)
        {:ok, cleaned_content}

      {:error, reason} ->
        Logger.error("Failed to parse PDF: #{inspect(reason)}")
        {:error, {:pdf_parse_error, reason}}
    end
  rescue
    error ->
      Logger.error("Exception parsing PDF: #{inspect(error)}")
      {:error, {:pdf_exception, error}}
  end

  @doc """
  Parses a .docx file (modern Word format) and extracts text.

  DOCX files are ZIP archives containing XML. We extract document.xml
  and parse the text content.
  """
  def parse_docx(file_path) do
    Logger.info("Parsing DOCX file: #{file_path}")

    try do
      # DOCX is a zip file - extract document.xml
      case :zip.unzip(to_charlist(file_path), [:memory]) do
        {:ok, files} ->
          # Find the main document XML
          case Enum.find(files, fn {name, _} ->
                 List.to_string(name) == "word/document.xml"
               end) do
            {_, xml_content} ->
              parse_docx_xml(xml_content)

            nil ->
              {:error, :docx_document_xml_not_found}
          end

        {:error, reason} ->
          Logger.error("Failed to unzip DOCX: #{inspect(reason)}")
          {:error, {:docx_unzip_error, reason}}
      end
    rescue
      error ->
        Logger.error("Exception parsing DOCX: #{inspect(error)}")
        {:error, {:docx_exception, error}}
    end
  end

  defp parse_docx_xml(xml_content) do
    # Simple approach: extract all text between <w:t> and </w:t> tags
    # This regex finds all content within w:t tags
    text =
      xml_content
      |> to_string()
      |> then(fn content ->
        # Match all <w:t>content</w:t> or <w:t xml:space="preserve">content</w:t>
        Regex.scan(~r/<w:t[^>]*>([^<]*)<\/w:t>/, content)
        |> Enum.map(fn [_, text] -> text end)
        |> Enum.join(" ")
      end)
      |> clean_text()

    if String.length(text) > 0 do
      {:ok, text}
    else
      {:error, :docx_no_text_extracted}
    end
  rescue
    error ->
      Logger.error("Exception parsing DOCX XML: #{inspect(error)}")
      {:error, {:docx_xml_exception, error}}
  end

  @doc """
  Parses a .doc file (legacy Word format).

  Legacy .doc files use a proprietary binary format. We'll attempt
  to extract readable text, but this is best-effort.
  """
  def parse_doc(file_path) do
    Logger.info("Parsing DOC file (legacy format): #{file_path}")

    # For legacy .doc files, we'll try basic text extraction
    # Note: This is a simplified approach and may not work for all .doc files
    case File.read(file_path) do
      {:ok, binary_content} ->
        # Try to extract ASCII/UTF-8 text from binary
        text =
          binary_content
          |> :binary.bin_to_list()
          |> Enum.filter(&(&1 >= 32 && &1 < 127))
          |> List.to_string()
          |> clean_text()

        if String.length(text) > 50 do
          {:ok, text}
        else
          {:error, :doc_insufficient_text_extracted}
        end

      {:error, reason} ->
        {:error, {:doc_read_error, reason}}
    end
  rescue
    error ->
      Logger.error("Exception parsing DOC: #{inspect(error)}")
      {:error, {:doc_exception, error}}
  end

  @doc """
  Parses a Markdown file.
  """
  def parse_markdown(file_path) do
    Logger.info("Parsing Markdown file: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        cleaned_content = clean_text(content)
        {:ok, cleaned_content}

      {:error, reason} ->
        {:error, {:markdown_read_error, reason}}
    end
  end

  @doc """
  Parses a plain text file.
  """
  def parse_text(file_path) do
    Logger.info("Parsing text file: #{file_path}")

    case File.read(file_path) do
      {:ok, content} ->
        cleaned_content = clean_text(content)
        {:ok, cleaned_content}

      {:error, reason} ->
        {:error, {:text_read_error, reason}}
    end
  end

  defp clean_text(text) when is_binary(text) do
    text
    |> String.trim()
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    # Replace multiple newlines with double newline
    |> String.replace(~r/\n{3,}/, "\n\n")
  end

  defp clean_text(_), do: ""
end
