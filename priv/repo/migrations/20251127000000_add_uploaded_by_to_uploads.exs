defmodule ArchitectureGenerator.Repo.Migrations.AddUploadedByToUploads do
  use Ecto.Migration

  def change do
    alter table(:uploads) do
      add :uploaded_by, :string
    end
  end
end
