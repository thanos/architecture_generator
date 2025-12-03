defmodule ArchitectureGenerator.Repo.Migrations.CreateLlmArtifacts do
  use Ecto.Migration

  def change do
    create table(:llm_artifacts) do
      add :type, :string, null: false
      add :category, :string, null: false
      add :title, :string, null: false
      add :content, :text
      add :prompt, :text, null: false
      add :project_id, references(:projects, on_delete: :delete_all), null: false

      timestamps()
    end

    create index(:llm_artifacts, [:project_id])
    create index(:llm_artifacts, [:type])
    create index(:llm_artifacts, [:category])
    create index(:llm_artifacts, [:inserted_at])
  end
end
