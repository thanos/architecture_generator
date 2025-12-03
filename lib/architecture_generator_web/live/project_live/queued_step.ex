defmodule ArchitectureGeneratorWeb.ProjectLive.QueuedStep do
  use ArchitectureGeneratorWeb, :live_component

  @impl true
  def update(assigns, socket) do
    {:ok, assign(socket, assigns)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
      <div class="text-center">
        <!-- Animated Loading Icon -->
        <div class="mb-6">
          <div class="w-20 h-20 mx-auto bg-gradient-to-br from-violet-500 to-cyan-500 rounded-full flex items-center justify-center animate-pulse">
            <.icon name="hero-cog-6-tooth" class="w-12 h-12 text-white animate-spin" />
          </div>
        </div>

        <h2 class="text-2xl font-bold text-slate-900 mb-4">
          Generating Your Architectural Plan
        </h2>

        <p class="text-slate-600 mb-6 max-w-md mx-auto">
          Our AI is analyzing your requirements and crafting a comprehensive architectural plan.
          This typically takes 10-20 minutes.
        </p>

    <!-- Progress Info -->
        <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6 max-w-md mx-auto">
          <div class="flex items-center justify-between mb-4">
            <span class="text-sm font-medium text-slate-700">Status</span>
            <span class="text-sm font-bold text-violet-600">In Progress</span>
          </div>

          <%= if @project.llm_job_id do %>
            <div class="flex items-center justify-between mb-4">
              <span class="text-sm font-medium text-slate-700">Job ID</span>
              <span class="text-sm font-mono text-slate-600">{@project.llm_job_id}</span>
            </div>
          <% end %>

          <div class="flex items-center justify-between">
            <span class="text-sm font-medium text-slate-700">Estimated Time</span>
            <span class="text-sm text-slate-600">10-20 minutes</span>
          </div>
        </div>

        <p class="text-sm text-slate-500 mt-6">
          You'll receive an email at
          <span class="font-medium text-slate-700">{@project.user_email}</span>
          {" "} when your plan is ready.
        </p>

    <!-- Auto-refresh notice -->
        <div class="mt-8 flex items-center justify-center gap-2 text-sm text-slate-500">
          <.icon name="hero-arrow-path" class="w-4 h-4 animate-spin" />
          <span>This page will automatically update when complete</span>
        </div>
      </div>
    </div>
    """
  end
end
