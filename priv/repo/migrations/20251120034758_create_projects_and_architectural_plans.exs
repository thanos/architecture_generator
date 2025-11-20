defmodule ArchitectureGenerator.Repo.Migrations.CreateProjectsAndArchitecturalPlans do
  use Ecto.Migration

  def change do
    create table(:architectural_plans) do
      add :content, :text
      add :generated_at, :naive_datetime

      timestamps()
    end

    create table(:projects) do
      add :name, :string, null: false
      add :brd_content, :text
      add :brd_file_path, :string
      add :status, :string, null: false, default: "Initial"
      add :elicitation_data, :map
      add :tech_stack_config, :map
      add :llm_job_id, :integer
      add :user_email, :string, null: false
      add :architectural_plan_id, references(:architectural_plans, on_delete: :nilify_all)

      timestamps()
    end

    create index(:projects, [:status])
    create index(:projects, [:architectural_plan_id])
  end
end
