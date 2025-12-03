defmodule ArchitectureGeneratorWeb.ArtifactLive.Show do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Artifacts

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    artifact = Artifacts.get_artifact!(id) |> ArchitectureGenerator.Repo.preload(:project)

    {:ok,
     socket
     |> assign(:page_title, "Artifact: #{artifact.title}")
     |> assign(:artifact, artifact)}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-violet-50 via-blue-50 to-cyan-50 py-12">
        <div class="max-w-5xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Back Button -->
          <div class="mb-6">
            <.link
              navigate={~p"/artifacts"}
              class="inline-flex items-center gap-2 text-slate-600 hover:text-slate-900 font-medium transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Artifacts
            </.link>
          </div>

          <!-- Artifact Details Card -->
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8 mb-6">
            <div class="flex items-start justify-between mb-6">
              <div class="flex items-start gap-4 flex-1">
                <div class="p-3 bg-gradient-to-br from-violet-100 to-cyan-100 rounded-xl">
                  <.icon name="hero-document-text" class="w-12 h-12 text-violet-600" />
                </div>
                <div class="flex-1">
                  <h1 class="text-2xl font-bold text-slate-900 mb-2">
                    {@artifact.title}
                  </h1>
                  <div class="flex items-center gap-4 text-sm text-slate-600 mb-4">
                    <span class="flex items-center gap-1">
                      <.icon name="hero-folder" class="w-4 h-4" />
                      <.link
                        navigate={~p"/projects/#{@artifact.project.id}"}
                        class="hover:text-violet-600 transition-colors"
                      >
                        {@artifact.project.name}
                      </.link>
                    </span>
                    <.type_badge type={@artifact.type} />
                    <.category_badge category={@artifact.category} />
                  </div>
                </div>
              </div>
            </div>

            <!-- Metadata Grid -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-slate-50 rounded-lg mb-6">
              <div>
                <p class="text-xs text-slate-500 mb-1">Type</p>
                <p class="text-sm font-medium text-slate-900">{@artifact.type}</p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">Category</p>
                <p class="text-sm font-medium text-slate-900">{@artifact.category}</p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">Created</p>
                <p class="text-sm font-medium text-slate-900">
                  {Calendar.strftime(@artifact.inserted_at, "%b %d, %Y at %I:%M %p")}
                </p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">Last Updated</p>
                <p class="text-sm font-medium text-slate-900">
                  {Calendar.strftime(@artifact.updated_at, "%b %d, %Y at %I:%M %p")}
                </p>
              </div>
            </div>

            <!-- Content Section -->
            <%= if @artifact.content do %>
              <div class="mb-6">
                <h2 class="text-lg font-bold text-slate-900 mb-4">Content</h2>
                <div class="bg-slate-50 rounded-lg p-6 border border-slate-200">
                  <pre class="whitespace-pre-wrap text-sm text-slate-900 font-mono overflow-x-auto">{@artifact.content}</pre>
                </div>
              </div>
            <% end %>

            <!-- Prompt Section -->
            <div>
              <h2 class="text-lg font-bold text-slate-900 mb-4">LLM Prompt</h2>
              <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6 border border-violet-200">
                <p class="text-sm text-slate-700 whitespace-pre-wrap">{@artifact.prompt}</p>
              </div>
            </div>
          </div>
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
end
