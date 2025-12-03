defmodule ArchitectureGenerator.Artifacts do
  @moduledoc """
  The Artifacts context handles all operations related to LLM-generated artifacts.
  """

  import Ecto.Query, warn: false
  alias ArchitectureGenerator.Repo
  alias ArchitectureGenerator.Artifacts.LlmArtifact

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
end
