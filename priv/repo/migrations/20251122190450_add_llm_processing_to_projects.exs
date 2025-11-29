defmodule ArchitectureGenerator.Repo.Migrations.AddLlmProcessingToProjects do
  use Ecto.Migration

  def change do
    alter table(:projects) do
      add :processing_mode, :string, default: "parse_only"
      add :llm_provider, :string
      add :llm_response, :text
    end
  end
end
