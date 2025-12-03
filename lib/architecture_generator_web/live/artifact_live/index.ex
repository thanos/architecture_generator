defmodule ArchitectureGeneratorWeb.ArtifactLive.Index do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.{Artifacts, Projects}

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "LLM Artifacts")
     |> assign(:artifacts, Artifacts.list_all_artifacts())
     |> assign(:search_query, "")
     |> assign(:filter_type, "")
     |> assign(:filter_category, "")
     |> assign(:filter_project_id, "")
     |> assign(:projects, Projects.list_projects())}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    artifacts = Artifacts.search_artifacts(query)

    {:noreply,
     socket
     |> assign(:artifacts, artifacts)
     |> assign(:search_query, query)}
  end

  @impl true
  def handle_event("filter", params, socket) do
    filters = %{
      type: params["type"] || "",
      category: params["category"] || "",
      project_id: params["project_id"] || ""
    }

    # Apply search query if present
    artifacts =
      if socket.assigns.search_query != "" do
        Artifacts.search_artifacts(socket.assigns.search_query)
        |> Enum.filter(fn artifact ->
          (filters.type == "" or artifact.type == filters.type) and
            (filters.category == "" or artifact.category == filters.category) and
            (filters.project_id == "" or
               to_string(artifact.project_id) == filters.project_id)
        end)
      else
        Artifacts.filter_artifacts(filters)
      end

    {:noreply,
     socket
     |> assign(:artifacts, artifacts)
     |> assign(:filter_type, filters.type)
     |> assign(:filter_category, filters.category)
     |> assign(:filter_project_id, filters.project_id)}
  end

  @impl true
  def handle_event("clear_filters", _params, socket) do
    {:noreply,
     socket
     |> assign(:artifacts, Artifacts.list_all_artifacts())
     |> assign(:search_query, "")
     |> assign(:filter_type, "")
     |> assign(:filter_category, "")
     |> assign(:filter_project_id, "")}
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
                <h1 class="text-3xl font-bold text-slate-900 mb-2">LLM Artifacts</h1>
                <p class="text-slate-600">
                  View and search all LLM-generated artifacts across all projects.
                </p>
              </div>
            </div>
          </div>

          <!-- Search and Filters -->
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-6 mb-6">
            <form phx-change="search" phx-submit="search" id="search-form">
              <div class="mb-4">
                <label for="search-query" class="block text-sm font-medium text-slate-700 mb-2">
                  Search Artifacts
                </label>
                <div class="flex items-center gap-2">
                  <div class="flex-1 relative">
                    <.icon
                      name="hero-magnifying-glass"
                      class="absolute left-3 top-1/2 transform -translate-y-1/2 w-5 h-5 text-slate-400"
                    />
                    <input
                      type="text"
                      id="search-query"
                      name="query"
                      value={@search_query}
                      placeholder="Search by title, content, or prompt..."
                      class="w-full pl-10 pr-4 py-3 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                    />
                  </div>
                </div>
              </div>
            </form>

            <form phx-change="filter" id="filter-form">
              <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
                <div>
                  <label for="filter-type" class="block text-sm font-medium text-slate-700 mb-2">
                    Type
                  </label>
                  <select
                    id="filter-type"
                    name="type"
                    class="w-full px-4 py-2 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  >
                    <option value="">All Types</option>
                    <option value="doc" selected={@filter_type == "doc"}>Document</option>
                    <option value="image" selected={@filter_type == "image"}>Image</option>
                    <option value="video" selected={@filter_type == "video"}>Video</option>
                    <option value="code" selected={@filter_type == "code"}>Code</option>
                    <option value="diagram" selected={@filter_type == "diagram"}>Diagram</option>
                    <option value="other" selected={@filter_type == "other"}>Other</option>
                  </select>
                </div>

                <div>
                  <label
                    for="filter-category"
                    class="block text-sm font-medium text-slate-700 mb-2"
                  >
                    Category
                  </label>
                  <select
                    id="filter-category"
                    name="category"
                    class="w-full px-4 py-2 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  >
                    <option value="">All Categories</option>
                    <option
                      value="Function Requirement Document"
                      selected={@filter_category == "Function Requirement Document"}
                    >
                      Function Requirement Document
                    </option>
                    <option
                      value="Design Document"
                      selected={@filter_category == "Design Document"}
                    >
                      Design Document
                    </option>
                    <option
                      value="Architectural Document"
                      selected={@filter_category == "Architectural Document"}
                    >
                      Architectural Document
                    </option>
                    <option
                      value="Technical Specification"
                      selected={@filter_category == "Technical Specification"}
                    >
                      Technical Specification
                    </option>
                    <option
                      value="API Documentation"
                      selected={@filter_category == "API Documentation"}
                    >
                      API Documentation
                    </option>
                    <option
                      value="Database Schema"
                      selected={@filter_category == "Database Schema"}
                    >
                      Database Schema
                    </option>
                    <option value="Other" selected={@filter_category == "Other"}>Other</option>
                  </select>
                </div>

                <div>
                  <label
                    for="filter-project"
                    class="block text-sm font-medium text-slate-700 mb-2"
                  >
                    Project
                  </label>
                  <select
                    id="filter-project"
                    name="project_id"
                    class="w-full px-4 py-2 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  >
                    <option value="">All Projects</option>
                    <%= for project <- @projects do %>
                      <option
                        value={project.id}
                        selected={@filter_project_id == to_string(project.id)}
                      >
                        {project.name}
                      </option>
                    <% end %>
                  </select>
                </div>

                <div class="flex items-end">
                  <button
                    type="button"
                    phx-click="clear_filters"
                    class="w-full px-4 py-2 bg-slate-200 text-slate-700 rounded-lg font-semibold hover:bg-slate-300 transition-colors"
                  >
                    Clear Filters
                  </button>
                </div>
              </div>
            </form>
          </div>

          <!-- Artifacts Grid -->
          <%= if @artifacts == [] do %>
            <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-12 text-center">
              <div class="w-16 h-16 bg-violet-100 rounded-full flex items-center justify-center mx-auto mb-4">
                <.icon name="hero-document-text" class="w-8 h-8 text-violet-600" />
              </div>
              <h3 class="text-xl font-bold text-slate-900 mb-2">No artifacts found</h3>
              <p class="text-slate-600">
                <%= if @search_query != "" or @filter_type != "" or @filter_category != "" or @filter_project_id != "" do %>
                  Try adjusting your search or filters.
                <% else %>
                  No LLM artifacts have been generated yet.
                <% end %>
              </p>
            </div>
          <% else %>
            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              <%= for artifact <- @artifacts do %>
                <.link
                  navigate={~p"/artifacts/#{artifact.id}"}
                  class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-6 hover:shadow-xl hover:border-violet-400 transition-all duration-300 group"
                >
                  <div class="flex items-start justify-between mb-4">
                    <div class="flex-1">
                      <h3 class="text-xl font-bold text-slate-900 mb-2 group-hover:text-violet-600 transition-colors line-clamp-2">
                        {artifact.title}
                      </h3>
                      <div class="flex items-center gap-2 mb-2">
                        <.type_badge type={artifact.type} />
                        <.category_badge category={artifact.category} />
                      </div>
                    </div>
                  </div>

                  <div class="mb-4">
                    <p class="text-sm text-slate-600 mb-2">
                      <span class="font-medium">Project:</span> {artifact.project.name}
                    </p>
                    <%= if artifact.content do %>
                      <p class="text-sm text-slate-600 line-clamp-3">
                        {String.slice(artifact.content, 0..150)}...
                      </p>
                    <% else %>
                      <p class="text-sm text-slate-400 italic">No content preview</p>
                    <% end %>
                  </div>

                  <div class="flex items-center justify-between text-xs text-slate-500 pt-4 border-t border-slate-200">
                    <span>
                      Created {format_date(artifact.inserted_at)}
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

  defp type_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-2 py-1 rounded-full text-xs font-medium",
      type_color(@type)
    ]}>
      {@type}
    </span>
    """
  end

  defp type_color(type) do
    case type do
      "doc" -> "bg-blue-100 text-blue-800"
      "image" -> "bg-purple-100 text-purple-800"
      "video" -> "bg-pink-100 text-pink-800"
      "code" -> "bg-green-100 text-green-800"
      "diagram" -> "bg-amber-100 text-amber-800"
      _ -> "bg-slate-100 text-slate-800"
    end
  end

  defp category_badge(assigns) do
    ~H"""
    <span class="inline-flex items-center px-2 py-1 rounded-full text-xs font-medium bg-violet-100 text-violet-800">
      {@category}
    </span>
    """
  end

  defp format_date(%NaiveDateTime{} = datetime) do
    "#{datetime.year}-#{String.pad_leading(to_string(datetime.month), 2, "0")}-#{String.pad_leading(to_string(datetime.day), 2, "0")}"
  end

  defp format_date(_), do: "N/A"
end
