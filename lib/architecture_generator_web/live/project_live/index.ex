defmodule ArchitectureGeneratorWeb.ProjectLive.Index do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Projects

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "All Projects")
     |> assign(:projects, Projects.list_projects())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("delete", %{"id" => _id}, socket) do
    # Note: You may want to add a delete function to Projects context
    # For now, we'll just refresh the list
    {:noreply,
     socket
     |> put_flash(:info, "Project deletion not yet implemented")
     |> assign(:projects, Projects.list_projects())}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-violet-50 via-blue-50 to-cyan-50 py-12">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Header -->
          <div class="mb-8">
            <div class="flex items-center justify-between mb-4">
              <div>
                <h1 class="text-3xl font-bold text-slate-900 mb-2">All Projects</h1>
                <p class="text-slate-600">
                  View and manage all your architectural projects.
                </p>
              </div>
              <.link
                navigate={~p"/projects/new"}
                class="px-6 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300 flex items-center gap-2"
              >
                <.icon name="hero-plus" class="w-5 h-5" />
                New Project
              </.link>
            </div>
          </div>

          <!-- Projects Grid -->
          <%= if @projects == [] do %>
            <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-12 text-center">
              <div class="w-16 h-16 bg-violet-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <.icon name="hero-folder" class="w-8 h-8 text-violet-600" />
              </div>
              <h3 class="text-xl font-bold text-slate-900 mb-2">No projects yet</h3>
              <p class="text-slate-600 mb-6">
                Get started by creating your first architectural project.
              </p>
              <.link
                navigate={~p"/projects/new"}
                class="inline-flex items-center px-6 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300"
              >
                Create Your First Project
                <.icon name="hero-arrow-right" class="w-5 h-5 ml-2" />
              </.link>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for project <- @projects do %>
                <.link
                  navigate={~p"/projects/#{project.id}"}
                  class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-6 hover:shadow-xl hover:border-violet-400 transition-all duration-300 group"
                >
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-xl font-bold text-slate-900 mb-2 group-hover:text-violet-600 transition-colors">
                        {project.name}
                      </h3>
                      <p class="text-sm text-slate-500 mb-2">
                        {project.user_email}
                      </p>
                    </div>
                    <.status_badge status={project.status} />
                  </div>

                  <div class="mb-4">
                    <p class="text-sm text-slate-600 line-clamp-2">
                      <%= if project.brd_content do %>
                        {String.slice(project.brd_content, 0..100)}...
                      <% else %>
                        <span class="text-slate-400 italic">No BRD content yet</span>
                      <% end %>
                    </p>
                  </div>

                  <div class="flex items-center justify-between text-xs text-slate-500 pt-4 border-t border-slate-200">
                    <span>
                      Created {format_date(project.inserted_at)}
                    </span>
                    <span class="flex items-center gap-1 text-violet-600 group-hover:text-violet-700">
                      View Details
                      <.icon name="hero-arrow-right" class="w-4 h-4" />
                    </span>
                  </div>
                </.link>
              <% end %>
            </div>
          <% end %>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium",
      status_color(@status)
    ]}>
      {@status}
    </span>
    """
  end

  defp status_color(status) do
    case status do
      "Initial" -> "bg-slate-100 text-slate-800"
      "Elicitation" -> "bg-blue-100 text-blue-800"
      "Tech_Stack_Input" -> "bg-violet-100 text-violet-800"
      "Queued" -> "bg-amber-100 text-amber-800"
      "Complete" -> "bg-emerald-100 text-emerald-800"
      "Error" -> "bg-red-100 text-red-800"
      _ -> "bg-slate-100 text-slate-800"
    end
  end

  defp format_date(%NaiveDateTime{} = datetime) do
    "#{datetime.year}-#{String.pad_leading(to_string(datetime.month), 2, "0")}-#{String.pad_leading(to_string(datetime.day), 2, "0")}"
  end

  defp format_date(_), do: "N/A"
end
