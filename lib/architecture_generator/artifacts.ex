defmodule ArchitectureGenerator.Artifacts do
  @moduledoc """
  The Artifacts context handles all operations related to LLM-generated artifacts.
  """

  import Ecto.Query, warn: false
  alias ArchitectureGenerator.Repo
  alias ArchitectureGenerator.Artifacts.LlmArtifact

  @doc """
  Returns the list of llm_artifacts for a project.

  ## Examples

      iex> list_artifacts_by_project(project)
      [%LlmArtifact{}, ...]

  """
  def list_artifacts_by_project(project) do
    LlmArtifact
    |> where([a], a.project_id == ^project.id)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Gets a single llm_artifact.

  Raises `Ecto.NoResultsError` if the Artifact does not exist.

  ## Examples

      iex> get_artifact!(123)
      %LlmArtifact{}

      iex> get_artifact!(456)
      ** (Ecto.NoResultsError)

  """
  def get_artifact!(id), do: Repo.get!(LlmArtifact, id)

  @doc """
  Creates a llm_artifact.

  ## Examples

      iex> create_artifact(%{field: value})
      {:ok, %LlmArtifact{}}

      iex> create_artifact(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_artifact(attrs \\ %{}) do
    %LlmArtifact{}
    |> LlmArtifact.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a llm_artifact.

  ## Examples

      iex> update_artifact(artifact, %{field: new_value})
      {:ok, %LlmArtifact{}}

      iex> update_artifact(artifact, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_artifact(%LlmArtifact{} = artifact, attrs) do
    artifact
    |> LlmArtifact.update_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a llm_artifact.

  ## Examples

      iex> delete_artifact(artifact)
      {:ok, %LlmArtifact{}}

      iex> delete_artifact(artifact)
      {:error, %Ecto.Changeset{}}

  """
  def delete_artifact(%LlmArtifact{} = artifact) do
    Repo.delete(artifact)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking artifact changes.

  ## Examples

      iex> change_artifact(artifact)
      %Ecto.Changeset{data: %LlmArtifact{}}

  """
  def change_artifact(%LlmArtifact{} = artifact, attrs \\ %{}) do
    LlmArtifact.changeset(artifact, attrs)
  end

  @doc """
  Lists artifacts by category for a project.

  ## Examples

      iex> list_artifacts_by_category(project, "Architectural Document")
      [%LlmArtifact{}, ...]

  """
  def list_artifacts_by_category(project, category) do
    LlmArtifact
    |> where([a], a.project_id == ^project.id and a.category == ^category)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Lists artifacts by type for a project.

  ## Examples

      iex> list_artifacts_by_type(project, "doc")
      [%LlmArtifact{}, ...]

  """
  def list_artifacts_by_type(project, type) do
    LlmArtifact
    |> where([a], a.project_id == ^project.id and a.type == ^type)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the list of all llm_artifacts with preloaded project.

  ## Examples

      iex> list_all_artifacts()
      [%LlmArtifact{}, ...]

  """
  def list_all_artifacts do
    LlmArtifact
    |> preload(:project)
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  @doc """
  Searches artifacts by query string (searches title, content, and prompt).

  ## Examples

      iex> search_artifacts("architecture")
      [%LlmArtifact{}, ...]

  """
  def search_artifacts(query) when is_binary(query) and query != "" do
    search_term = "%#{query}%"

    LlmArtifact
    |> preload(:project)
    |> where(
      [a],
      ilike(a.title, ^search_term) or
        ilike(a.content, ^search_term) or
        ilike(a.prompt, ^search_term)
    )
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  def search_artifacts(_), do: list_all_artifacts()

  @doc """
  Filters artifacts by type, category, and/or project_id.

  ## Examples

      iex> filter_artifacts(%{type: "doc", category: "Architectural Document"})
      [%LlmArtifact{}, ...]

  """
  def filter_artifacts(filters \\ %{}) do
    LlmArtifact
    |> preload(:project)
    |> filter_by_type(filters[:type])
    |> filter_by_category(filters[:category])
    |> filter_by_project(filters[:project_id])
    |> order_by([a], desc: a.inserted_at)
    |> Repo.all()
  end

  defp filter_by_type(query, nil), do: query
  defp filter_by_type(query, ""), do: query

  defp filter_by_type(query, type) do
    where(query, [a], a.type == ^type)
  end

  defp filter_by_category(query, nil), do: query
  defp filter_by_category(query, ""), do: query

  defp filter_by_category(query, category) do
    where(query, [a], a.category == ^category)
  end

  defp filter_by_project(query, nil), do: query
  defp filter_by_project(query, ""), do: query

  defp filter_by_project(query, project_id) when is_binary(project_id) do
    filter_by_project(query, String.to_integer(project_id))
  end

  defp filter_by_project(query, project_id) when is_integer(project_id) do
    where(query, [a], a.project_id == ^project_id)
  end
end
