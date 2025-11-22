defmodule ArchitectureGenerator.Repo.Migrations.CreateUploadsAndVersions do
  use Ecto.Migration

  def change do
    create table(:uploads) do
      add :filename, :string, null: false
      add :content_type, :string
      add :size_bytes, :bigint
      add :s3_key, :string, null: false
      add :s3_bucket, :string, null: false
      add :current_version, :integer, default: 1
      add :project_id, references(:projects, on_delete: :delete_all)

      timestamps()
    end

    create index(:uploads, [:project_id])
    create unique_index(:uploads, [:s3_key, :s3_bucket])

    create table(:upload_versions) do
      add :upload_id, references(:uploads, on_delete: :delete_all), null: false
      add :version_number, :integer, null: false
      add :filename, :string, null: false
      add :content_type, :string
      add :size_bytes, :bigint
      add :s3_key, :string, null: false
      add :s3_bucket, :string, null: false
      add :uploaded_by, :string

      timestamps()
    end

    create index(:upload_versions, [:upload_id])
    create unique_index(:upload_versions, [:upload_id, :version_number])
  end
end
