defmodule ArchitectureGenerator.Plans.ArchitecturalPlan do
  use Ecto.Schema
  import Ecto.Changeset

  schema "architectural_plans" do
    field :content, :string
    field :generated_at, :naive_datetime

    has_one :project, ArchitectureGenerator.Projects.Project

    timestamps()
  end

  @doc """
  Changeset for creating a new architectural plan
  """
  def create_changeset(architectural_plan, attrs) do
    architectural_plan
    |> cast(attrs, [:content, :generated_at])
    |> validate_required([:content])
    |> validate_length(:content, min: 100, message: "must be a substantial architectural plan")
  end

  @doc """
  Changeset for updating an architectural plan
  """
  def update_changeset(architectural_plan, attrs) do
    architectural_plan
    |> cast(attrs, [:content])
    |> validate_required([:content])
    |> validate_length(:content, min: 100, message: "must be a substantial architectural plan")
  end
end
