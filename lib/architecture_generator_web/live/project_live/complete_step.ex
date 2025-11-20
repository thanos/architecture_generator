defmodule ArchitectureGeneratorWeb.ProjectLive.CompleteStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.Plans

  @impl true
  def update(assigns, socket) do
    architectural_plan =
      if assigns.project.architectural_plan_id do
        Plans.get_plan_by_project!(assigns.project)
      else
        nil
      end

    socket =
      socket
      |> assign(assigns)
      |> assign(:architectural_plan, architectural_plan)

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
      <div class="text-center mb-8">
        <!-- Success Icon -->
        <div class="mb-6">
          <div class="w-20 h-20 mx-auto bg-gradient-to-br from-emerald-500 to-cyan-500 rounded-full flex items-center justify-center">
            <.icon name="hero-check-circle" class="w-12 h-12 text-white" />
          </div>
        </div>

        <h2 class="text-2xl font-bold text-slate-900 mb-4">
          Your Architectural Plan is Ready!
        </h2>

        <p class="text-slate-600 mb-6 max-w-md mx-auto">
          We've successfully generated a comprehensive IT architectural plan based on your requirements.
        </p>
      </div>

      <%= if @architectural_plan do %>
        <!-- Plan Preview -->
        <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6 mb-6">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-lg font-bold text-slate-900">Architectural Plan</h3>
            <span class="text-sm text-slate-600">
              Generated {Calendar.strftime(@architectural_plan.inserted_at, "%B %d, %Y")}
            </span>
          </div>
          
    <!-- Plan Content Preview -->
          <div class="bg-white rounded-lg p-4 max-h-96 overflow-y-auto">
            <pre class="text-sm text-slate-700 whitespace-pre-wrap font-mono">{String.slice(
              @architectural_plan.content,
              0,
              500
            )}...</pre>
          </div>
        </div>
        
    <!-- Action Buttons -->
        <div class="flex items-center justify-center gap-4">
          <button
            phx-click="download_plan"
            class="px-8 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300"
          >
            <.icon name="hero-arrow-down-tray" class="w-5 h-5 inline-block mr-2" />
            Download Plan (Markdown)
          </button>

          <button
            phx-click="view_full_plan"
            class="px-8 py-3 bg-white text-violet-600 rounded-xl font-semibold border-2 border-violet-600 hover:bg-violet-50 transition-all duration-300"
          >
            <.icon name="hero-document-text" class="w-5 h-5 inline-block mr-2" /> View Full Plan
          </button>
        </div>
      <% else %>
        <div class="text-center text-slate-600">
          <p>Plan data not available. Please contact support.</p>
        </div>
      <% end %>
    </div>
    """
  end
end
