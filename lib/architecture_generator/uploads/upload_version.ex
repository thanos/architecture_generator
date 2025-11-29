defmodule ArchitectureGenerator.Uploads.UploadVersion do
  use Ecto.Schema
  import Ecto.Changeset

  schema "upload_versions" do
    field :version_number, :integer
    field :filename, :string
    field :content_type, :string
    field :size_bytes, :integer
    field :s3_key, :string
    field :s3_bucket, :string
    field :uploaded_by, :string

    belongs_to :upload, ArchitectureGenerator.Uploads.Upload

    timestamps()
  end

  @doc """
  Changeset for creating a new upload version
  """
  def create_changeset(version, attrs) do
    version
    |> cast(attrs, [
      :version_number,
      :filename,
      :content_type,
      :size_bytes,
      :s3_key,
      :s3_bucket,
      :uploaded_by,
      :upload_id
    ])
    |> validate_required([:version_number, :filename, :s3_key, :s3_bucket, :upload_id])
    |> validate_length(:filename, min: 1, max: 255)
    |> validate_number(:version_number, greater_than: 0)
    |> unique_constraint([:upload_id, :version_number])
    |> foreign_key_constraint(:upload_id)
  end
end
