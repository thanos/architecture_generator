defmodule ArchitectureGenerator.Plans do
  @moduledoc """
  The Plans context handles all operations related to architectural plans.
  """

  import Ecto.Query, warn: false
  alias ArchitectureGenerator.Repo
  alias ArchitectureGenerator.Plans.ArchitecturalPlan

  @doc """
  Creates an architectural plan.

  ## Examples

      iex> create_architectural_plan(%{content: "..."})
      {:ok, %ArchitecturalPlan{}}

      iex> create_architectural_plan(%{content: nil})
      {:error, %Ecto.Changeset{}}

  """
  def create_architectural_plan(attrs \\ %{}) do
    %ArchitecturalPlan{}
    |> ArchitecturalPlan.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Gets an architectural plan by project ID.

  Raises `Ecto.NoResultsError` if the Plan does not exist.

  ## Examples

      iex> get_plan_by_project!(project)
      %ArchitecturalPlan{}

  """
  def get_plan_by_project!(project) do
    Repo.get_by!(ArchitecturalPlan, id: project.architectural_plan_id)
  end
end
