defmodule ArchitectureGenerator.Projects do
  @moduledoc """
  The Projects context handles all operations related to projects.
  """

  import Ecto.Query, warn: false
  alias ArchitectureGenerator.Repo
  alias ArchitectureGenerator.Projects.Project

  @doc """
  Returns the list of projects.

  ## Examples

      iex> list_projects()
      [%Project{}, ...]

  """
  def list_projects do
    Repo.all(Project)
  end

  @doc """
  Gets a single project.

  Raises `Ecto.NoResultsError` if the Project does not exist.

  ## Examples

      iex> get_project!(123)
      %Project{}

      iex> get_project!(456)
      ** (Ecto.NoResultsError)

  """
  def get_project!(id), do: Repo.get!(Project, id)

  @doc """
  Creates a project.

  ## Examples

      iex> create_project(%{field: value})
      {:ok, %Project{}}

      iex> create_project(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_project(attrs \\ %{}) do
    %Project{}
    |> Project.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a project status and related data.

  ## Examples

      iex> update_project_status(project, "Elicitation")
      {:ok, %Project{}}

      iex> update_project_status(project, "Invalid")
      {:error, %Ecto.Changeset{}}

  """
  def update_project_status(project, status) do
    case status do
      "Elicitation" ->
        project
        |> Project.transition_to_elicitation()
        |> Repo.update()

      _ ->
        {:error, :invalid_status_transition}
    end
  end

  @doc """
  Saves elicitation data and transitions to Tech_Stack_Input status.
  """
  def save_elicitation_data(project, elicitation_data) do
    project
    |> Project.save_elicitation_changeset(elicitation_data)
    |> Repo.update()
  end

  @doc """
  Saves tech stack configuration and transitions to Queued status.
  """
  def save_tech_stack_config(project, tech_stack_config) do
    project
    |> Project.save_tech_stack_changeset(tech_stack_config)
    |> Repo.update()
  end

  @doc """
  Marks a project as complete with the architectural plan ID.
  """
  def complete_project(project, architectural_plan_id) do
    project
    |> Project.complete_changeset(architectural_plan_id)
    |> Repo.update()
  end

  @doc """
  Marks a project as error.
  """
  def mark_project_error(project) do
    project
    |> Project.error_changeset()
    |> Repo.update()
  end

  @doc """
  Updates BRD content for a project.
  """
  def update_brd_content(project, attrs) do
    project
    |> Project.update_brd_changeset(attrs)
    |> Repo.update()
  end
end
