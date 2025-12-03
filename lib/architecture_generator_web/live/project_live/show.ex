defmodule ArchitectureGeneratorWeb.ProjectLive.Show do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Projects

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    project = Projects.get_project!(id)

    socket =
      socket
      |> assign(:project, project)
      |> assign(:page_title, "Project: #{project.name}")
      |> allow_upload(:brd_file,
        accept: ~w(.txt .md .pdf .doc .docx),
        max_entries: 1,
        max_file_size: 10_000_000
      )

    {:ok, socket}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_info({:refresh_project, project_id}, socket) do
    project = Projects.get_project!(project_id)
    {:noreply, assign(socket, :project, project)}
  end

  @impl true
  def handle_info({:update_parsing_status, status}, socket) do
    # Forward parsing status updates to the InitialStep component
    send_update(ArchitectureGeneratorWeb.ProjectLive.InitialStep,
      id: "initial-step",
      parsing_status: status
    )
    {:noreply, socket}
  end

  @impl true
  def handle_info({:show_content_preview, preview}, socket) do
    # Forward content preview to the InitialStep component
    send_update(ArchitectureGeneratorWeb.ProjectLive.InitialStep,
      id: "initial-step",
      parsed_content_preview: preview
    )
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-violet-50 via-blue-50 to-cyan-50 py-12">
        <div class="max-w-4xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Progress Header -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-slate-900 mb-2">{@project.name}</h1>
            <div class="flex items-center gap-4">
              <.status_badge status={@project.status} />
              <span class="text-sm text-slate-600">{@project.user_email}</span>
            </div>
          </div>

    <!-- Progress Steps -->
          <.progress_steps current_status={@project.status} />

    <!-- Step Content -->
          <div class="mt-8">
            <%= case @project.status do %>
              <% "Initial" -> %>
                <.live_component
                  module={ArchitectureGeneratorWeb.ProjectLive.InitialStep}
                  id="initial-step"
                  project={@project}
                  uploads={@uploads}
                />
              <% "Elicitation" -> %>
                <.live_component
                  module={ArchitectureGeneratorWeb.ProjectLive.ElicitationStep}
                  id="elicitation-step"
                  project={@project}
                />
              <% "Tech_Stack_Input" -> %>
                <.live_component
                  module={ArchitectureGeneratorWeb.ProjectLive.TechStackStep}
                  id="tech-stack-step"
                  project={@project}
                />
              <% "Queued" -> %>
                <.live_component
                  module={ArchitectureGeneratorWeb.ProjectLive.QueuedStep}
                  id="queued-step"
                  project={@project}
                />
              <% "Complete" -> %>
                <.live_component
                  module={ArchitectureGeneratorWeb.ProjectLive.CompleteStep}
                  id="complete-step"
                  project={@project}
                />
              <% "Error" -> %>
                <div class="bg-red-50 border border-red-200 rounded-xl p-6">
                  <h3 class="text-lg font-bold text-red-900 mb-2">Generation Error</h3>
                  <p class="text-red-700">
                    An error occurred while generating your architectural plan.
                    Please try creating a new project or contact support.
                  </p>
                </div>
              <% _ -> %>
                <div class="text-center text-slate-600">Unknown status</div>
            <% end %>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp status_badge(assigns) do
    ~H"""
    <span class={[
      "inline-flex items-center px-3 py-1 rounded-full text-sm font-medium",
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

  defp progress_steps(assigns) do
    ~H"""
    <div class="bg-white/60 backdrop-blur-sm rounded-xl border border-violet-200 p-6">
      <div class="flex items-center justify-between">
        <.step_indicator step={1} label="Upload BRD" status={step_status(1, @current_status)} />
        <div class="flex-1 h-1 mx-4 bg-slate-200 rounded"></div>
        <.step_indicator step={2} label="Elicitation" status={step_status(2, @current_status)} />
        <div class="flex-1 h-1 mx-4 bg-slate-200 rounded"></div>
        <.step_indicator step={3} label="Tech Stack" status={step_status(3, @current_status)} />
        <div class="flex-1 h-1 mx-4 bg-slate-200 rounded"></div>
        <.step_indicator step={4} label="Generation" status={step_status(4, @current_status)} />
        <div class="flex-1 h-1 mx-4 bg-slate-200 rounded"></div>
        <.step_indicator step={5} label="Complete" status={step_status(5, @current_status)} />
      </div>
    </div>
    """
  end

  defp step_indicator(assigns) do
    ~H"""
    <div class="flex flex-col items-center">
      <div class={[
        "w-10 h-10 rounded-full flex items-center justify-center font-bold text-sm mb-2",
        case @status do
          :complete -> "bg-emerald-500 text-white"
          :current -> "bg-violet-600 text-white"
          :pending -> "bg-slate-200 text-slate-500"
        end
      ]}>
        {@step}
      </div>
      <span class="text-xs text-slate-600 text-center">{@label}</span>
    </div>
    """
  end

  defp step_status(step_num, current_status) do
    current_step =
      case current_status do
        "Initial" -> 1
        "Elicitation" -> 2
        "Tech_Stack_Input" -> 3
        "Queued" -> 4
        "Complete" -> 5
        "Error" -> 5
        _ -> 0
      end

    cond do
      step_num < current_step -> :complete
      step_num == current_step -> :current
      true -> :pending
    end
  end
end
