defmodule ArchitectureGeneratorWeb.ProjectLive.TechStackStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.Projects
  alias ArchitectureGenerator.Workers.PlanGenerationWorker
  alias Oban

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:tech_stack, assigns.project.tech_stack_config || %{})

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_stack", params, socket) do
    tech_stack = Map.merge(socket.assigns.tech_stack, params)
    {:noreply, assign(socket, :tech_stack, tech_stack)}
  end

  @impl true
  def handle_event("submit_stack", _params, socket) do
    require Logger

    project = socket.assigns.project
    tech_stack = socket.assigns.tech_stack

    Logger.info("TechStackStep: submit_stack called for project #{project.id}")
    Logger.info("TechStackStep: project status = #{project.status}")
    Logger.info("TechStackStep: tech_stack = #{inspect(tech_stack)}")

    # Verify project is in the correct status before saving
    if project.status != "Tech_Stack_Input" do
      Logger.error("TechStackStep: Project #{project.id} is not in Tech_Stack_Input status (current: #{project.status})")
      {:noreply,
       socket
       |> put_flash(
         :error,
         "Project is not in the correct status. Please refresh the page and try again."
       )}
    else
      Logger.info("TechStackStep: saving tech stack config and creating Oban job")

      case Projects.save_tech_stack_config(project, tech_stack) do
        {:ok, updated_project} ->
          Logger.info("TechStackStep: tech stack saved, project status = #{updated_project.status}")
          Logger.info("TechStackStep: creating Oban job for project #{updated_project.id}")

          # Enqueue the Oban job to generate the architectural plan
          job = PlanGenerationWorker.new(%{project_id: updated_project.id})
          Logger.info("TechStackStep: job created: #{inspect(job)}")

          case Oban.insert(job) do
            {:ok, inserted_job} ->
              Logger.info("TechStackStep: Oban job inserted successfully with ID: #{inserted_job.id}")
              send(self(), {:refresh_project, updated_project.id})
              {:noreply,
               socket
               |> put_flash(:info, "Plan generation job queued successfully. This may take a few minutes.")}

            {:error, changeset} ->
              Logger.error("TechStackStep: Failed to insert Oban job: #{inspect(changeset.errors)}")
              Logger.error("TechStackStep: Changeset: #{inspect(changeset)}")
              {:noreply,
               socket
               |> put_flash(
                 :error,
                 "Failed to enqueue plan generation: #{inspect(changeset.errors)}"
               )}
          end

        {:error, changeset} ->
          Logger.error("TechStackStep: Failed to save tech stack config: #{inspect(changeset.errors)}")
          Logger.error("TechStackStep: Changeset: #{inspect(changeset)}")
          {:noreply,
           socket
           |> put_flash(
             :error,
             "Failed to save tech stack configuration: #{inspect(changeset.errors)}"
           )}
      end
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    project = socket.assigns.project
    tech_stack = socket.assigns.tech_stack

    # Save tech stack as draft before going back so user's inputs are preserved
    case Projects.update_tech_stack_config(project, tech_stack) do
      {:ok, updated_project} ->
        # Now go back to Elicitation
        case Projects.go_back_to_status(updated_project, "Elicitation") do
          {:ok, _final_project} ->
            send(self(), {:refresh_project, updated_project.id})
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to go back to previous step")}
        end

      {:error, _changeset} ->
        # Even if saving draft fails, try to go back anyway
        case Projects.go_back_to_status(project, "Elicitation") do
          {:ok, _updated_project} ->
            send(self(), {:refresh_project, project.id})
            {:noreply, socket}

          {:error, _reason} ->
            {:noreply, put_flash(socket, :error, "Failed to go back to previous step")}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
      <h2 class="text-2xl font-bold text-slate-900 mb-6">
        Technology Stack Selection
      </h2>

      <p class="text-slate-600 mb-6">
        Select your preferred technology stack. This will guide the architectural recommendations.
      </p>

      <form
        phx-change="validate_stack"
        phx-submit="submit_stack"
        phx-target={@myself}
        id="tech-stack-form"
      >
        <div class="space-y-6">
          <!-- Primary Language -->
          <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
            <label for="primary_language" class="block text-sm font-bold text-slate-900 mb-3">
              Primary Programming Language
            </label>
            <select
              id="primary_language"
              name="primary_language"
              class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
            >
              <option value="">Select a language...</option>
              <%= for lang <- ["Python", "Java", "Go", "Elixir", "Node.js", "Ruby", "C#", "PHP"] do %>
                <option value={lang} selected={Map.get(@tech_stack, "primary_language") == lang}>
                  {lang}
                </option>
              <% end %>
            </select>
            <p class="text-xs text-slate-500 mt-2">
              The primary language for your application backend.
            </p>
          </div>

    <!-- Web Framework -->
          <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
            <label for="web_framework" class="block text-sm font-bold text-slate-900 mb-3">
              Web Framework
            </label>
            <input
              type="text"
              id="web_framework"
              name="web_framework"
              value={Map.get(@tech_stack, "web_framework", "")}
              class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
              placeholder="e.g., Phoenix, Django, Spring Boot, Express.js, Rails"
            />
            <p class="text-xs text-slate-500 mt-2">
              The web framework for building your application.
            </p>
          </div>

    <!-- Database System -->
          <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
            <label for="database_system" class="block text-sm font-bold text-slate-900 mb-3">
              Database System
            </label>
            <select
              id="database_system"
              name="database_system"
              class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
            >
              <option value="">Select a database...</option>
              <%= for db <- ["PostgreSQL", "MySQL", "MongoDB", "Cassandra", "Redis", "DynamoDB", "SQLite"] do %>
                <option value={db} selected={Map.get(@tech_stack, "database_system") == db}>
                  {db}
                </option>
              <% end %>
            </select>
            <p class="text-xs text-slate-500 mt-2">
              Primary database system for data storage.
            </p>
          </div>

    <!-- Deployment Environment -->
          <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
            <label for="deployment_env" class="block text-sm font-bold text-slate-900 mb-3">
              Deployment Environment
            </label>
            <select
              id="deployment_env"
              name="deployment_env"
              class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
            >
              <option value="">Select deployment environment...</option>
              <%= for env <- ["AWS", "Azure", "Google Cloud Platform", "On-Premise", "Kubernetes", "Docker", "Fly.io", "Heroku"] do %>
                <option value={env} selected={Map.get(@tech_stack, "deployment_env") == env}>
                  {env}
                </option>
              <% end %>
            </select>
            <p class="text-xs text-slate-500 mt-2">
              Where your application will be deployed.
            </p>
          </div>
        </div>

        <div class="flex items-center justify-between gap-4 mt-8">
          <button
            type="button"
            phx-click="go_back"
            phx-target={@myself}
            class="px-6 py-3 bg-slate-200 text-slate-700 rounded-xl font-semibold hover:bg-slate-300 transition-all duration-300 flex items-center gap-2"
          >
            <.icon name="hero-arrow-left" class="w-5 h-5" />
            Back to Elicitation
          </button>

          <button
            type="submit"
            disabled={!all_fields_filled?(@tech_stack)}
            class="px-8 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none"
          >
            Submit for Generation <.icon name="hero-arrow-right" class="w-5 h-5 inline-block ml-2" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp all_fields_filled?(tech_stack) do
    required_fields = ["primary_language", "database_system", "deployment_env"]
    Enum.all?(required_fields, fn field -> Map.get(tech_stack, field, "") != "" end)
  end
end
