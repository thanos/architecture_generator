defmodule ArchitectureGeneratorWeb.ProjectLive.New do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Projects
  alias ArchitectureGenerator.Projects.Project

  @impl true
  def mount(_params, _session, socket) do
    changeset = Project.create_changeset(%Project{}, %{})

    socket =
      socket
      |> assign(:page_title, "Create New Project")
      |> assign(:changeset, changeset)
      |> assign(:form, to_form(changeset))

    {:ok, socket}
  end

  @impl true
  def handle_event("validate", %{"project" => project_params}, socket) do
    changeset =
      %Project{}
      |> Project.create_changeset(project_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, :changeset, changeset)}
  end

  @impl true
  def handle_event("save", %{"project" => project_params}, socket) do
    case Projects.create_project(project_params) do
      {:ok, project} ->
        {:noreply,
         socket
         |> put_flash(:info, "Project created successfully!")
         |> push_navigate(to: ~p"/projects/#{project.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :changeset, changeset)     |> put_flash(:error, "Failed to create the project")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-violet-50 via-blue-50 to-cyan-50 py-12">
        <div class="max-w-2xl mx-auto px-4 sm:px-6 lg:px-8">
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-slate-900 mb-2">Create New Project</h1>
            <p class="text-slate-600">
              Start by providing basic information about your project. You'll upload your BRD in the next step.
            </p>
          </div>

          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
            <.form
              for={@form}
              for={@changeset}
              phx-change="validate"
              phx-submit="save"
              id="new-project-form"
              class="space-y-6"
            >
              <!-- Project Name -->
              <div>
                <label for="project-name" class="block text-sm font-bold text-slate-900 mb-2">
                  Project Name
                </label>
                <.input
                  field={@form[:name]}
                  type="text"
                  placeholder="e.g., E-commerce Platform Redesign"
                  class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  error_class="border-red-400 focus:border-red-500 focus:ring focus:ring-red-300"
                />
              </div>

    <!-- User Email -->
              <div>
                <label for="user-email" class="block text-sm font-bold text-slate-900 mb-2">
                  Your Email
                </label>
                <.input
                  field={@form[:user_email]}
                  type="email"
                  placeholder="you@example.com"
                  class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  error_class="border-red-400 focus:border-red-500 focus:ring focus:ring-red-300"
                />
                <p class="text-xs text-slate-500 mt-2">
                  We'll send you a notification when your architectural plan is ready.
                </p>
              </div>

    <!-- Submit Button -->
              <div class="flex items-center justify-between pt-4">
                <.link
                  navigate={~p"/"}
                  class="text-slate-600 hover:text-slate-900 font-medium transition-colors"
                >
                  ← Back to Home
                </.link>

                <button
                  type="submit"
                  class="px-8 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  Create Project <.icon name="hero-arrow-right" class="w-5 h-5 inline-block ml-2" />
                </button>
              </div>
            </.form>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
