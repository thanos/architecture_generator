defmodule ArchitectureGenerator.Projects.Project do
  use Ecto.Schema
  import Ecto.Changeset

  schema "projects" do
    field :name, :string
    field :brd_content, :string
    field :brd_file_path, :string
    field :status, :string, default: "Initial"
    field :elicitation_data, :map, default: %{}
    field :tech_stack_config, :map, default: %{}
    field :llm_job_id, :integer
    field :user_email, :string

    field :processing_mode, :string, default: "parse_only"
    field :llm_provider, :string
    field :llm_response, :string

    belongs_to :architectural_plan, ArchitectureGenerator.Plans.ArchitecturalPlan

    timestamps()
  end

  @doc """
  Changeset for creating a new project (Initial status)
  """
  def create_changeset(project, attrs) do
    project
    |> cast(attrs, [:name, :user_email, :brd_content, :brd_file_path, :processing_mode, :llm_provider])
    |> validate_required([:name, :user_email])
    |> validate_format(:user_email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
    # |> validate_brd_content()
    |> put_change(:status, "Initial")
  end

  @doc """
  Changeset for transitioning to Elicitation status
  """
  def transition_to_elicitation(project, attrs \\ %{}) do
    project
    |> cast(attrs, [])
    |> validate_required([:brd_content])
    |> validate_inclusion(:status, ["Initial"])
    |> put_change(:status, "Elicitation")
  end

  @doc """
  Changeset for saving elicitation data and transitioning to Tech_Stack_Input
  """
  def save_elicitation_changeset(project, elicitation_data) do
    project
    |> cast(%{}, [])
    |> validate_inclusion(:status, ["Elicitation"])
    |> put_change(:elicitation_data, elicitation_data)
    |> put_change(:status, "Tech_Stack_Input")
  end

  @doc """
  Changeset for saving tech stack config and transitioning to Queued
  """
  def save_tech_stack_changeset(project, tech_stack_config) do
    project
    |> cast(%{}, [])
    |> validate_inclusion(:status, ["Tech_Stack_Input"])
    |> put_change(:tech_stack_config, tech_stack_config)
    |> put_change(:status, "Queued")
  end

  @doc """
  Changeset for saving tech stack config as draft (without changing status)
  """
  def update_tech_stack_changeset(project, tech_stack_config) do
    project
    |> cast(%{}, [])
    |> validate_inclusion(:status, ["Tech_Stack_Input"])
    |> put_change(:tech_stack_config, tech_stack_config)
  end

  @doc """
  Changeset for marking as complete with architectural plan
  """
  def complete_changeset(project, architectural_plan_id) do
    project
    |> cast(%{}, [])
    |> validate_inclusion(:status, ["Queued"])
    |> put_change(:architectural_plan_id, architectural_plan_id)
    |> put_change(:status, "Complete")
  end

  @doc """
  Changeset for marking as error
  """
  def error_changeset(project) do
    project
    |> cast(%{}, [])
    |> put_change(:status, "Error")
  end

  @doc """
  Changeset for updating BRD content
  """
  def update_brd_changeset(project, attrs) do
    project
    |> cast(attrs, [:brd_content, :brd_file_path])
    |> validate_brd_content()
  end

  @doc """
  Changeset for saving draft BRD inputs (brd_content, processing_mode, llm_provider)
  without changing status. Used to persist user inputs when navigating away.
  """
  def save_draft_brd_changeset(project, attrs) do
    project
    |> cast(attrs, [:brd_content, :processing_mode, :llm_provider])
    # Don't validate required fields for drafts - allow partial saves
  end

  defp validate_brd_content(changeset) do
    brd_content = get_field(changeset, :brd_content)
    brd_file_path = get_field(changeset, :brd_file_path)

    if is_nil(brd_content) and is_nil(brd_file_path) do
      add_error(changeset, :brd_content, "must provide either BRD content or upload a file")
    else
      changeset
    end
  end
end
