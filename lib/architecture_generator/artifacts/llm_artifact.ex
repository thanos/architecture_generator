defmodule ArchitectureGenerator.Artifacts.LlmArtifact do
  use Ecto.Schema
  import Ecto.Changeset

  @valid_types ["doc", "image", "video", "code", "diagram", "other"]
  @valid_categories [
    "Function Requirement Document",
    "Design Document",
    "Architectural Document",
    "Technical Specification",
    "API Documentation",
    "Database Schema",
    "Other"
  ]

  schema "llm_artifacts" do
    field :type, :string
    field :category, :string
    field :title, :string
    field :content, :string
    field :prompt, :string

    belongs_to :project, ArchitectureGenerator.Projects.Project

    timestamps()
  end

  @doc false
  def changeset(llm_artifact, attrs) do
    llm_artifact
    |> cast(attrs, [:type, :category, :title, :content, :prompt, :project_id])
    |> validate_required([:type, :category, :title, :prompt, :project_id])
    |> validate_inclusion(:type, @valid_types, message: "must be one of: #{Enum.join(@valid_types, ", ")}")
    |> validate_inclusion(:category, @valid_categories, message: "must be one of: #{Enum.join(@valid_categories, ", ")}")
    |> validate_length(:title, min: 1, max: 255)
    |> foreign_key_constraint(:project_id)
  end

  @doc """
  Changeset for creating a new LLM artifact
  """
  def create_changeset(llm_artifact, attrs) do
    changeset(llm_artifact, attrs)
  end

  @doc """
  Changeset for updating an LLM artifact
  """
  def update_changeset(llm_artifact, attrs) do
    changeset(llm_artifact, attrs)
  end
end
