defmodule ArchitectureGeneratorWeb.ProjectLive.InitialStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.Projects

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     # |> assign(assigns)
     |> assign(:brd_text, assigns.project.brd_content || "")}
  end

  @impl true
  def handle_event("validate_brd", %{"brd_text" => brd_text}, socket) do
    {:noreply, assign(socket, :brd_text, brd_text)}
  end

  @impl true
  def handle_event("submit_brd", %{"brd_text" => brd_text}, socket) do
    project = socket.assigns.project

    case Projects.update_brd_content(project, %{brd_content: brd_text}) do
      {:ok, updated_project} ->
        case Projects.update_project_status(updated_project, "Elicitation") do
          {:ok, _project} ->
            send(self(), {:refresh_project, updated_project.id})
            {:noreply, socket}

          {:error, _} ->
            {:noreply, put_flash(socket, :error, "Failed to transition to elicitation")}
        end

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Please provide BRD content")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
      <h2 class="text-2xl font-bold text-slate-900 mb-6">
        Upload Your Business Requirements Document
      </h2>

      <p class="text-slate-600 mb-6">
        Provide your BRD by pasting the content below or uploading a file.
        Our AI will analyze it to generate a comprehensive architectural plan.
      </p>

      <form phx-change="validate_brd" phx-submit="submit_brd" phx-target={@myself} id="brd-form">
        <!-- BRD Text Area -->
        <div class="mb-6">
          <label for="brd-text" class="block text-sm font-medium text-slate-700 mb-2">
            Business Requirements Document
          </label>
          <textarea
            id="brd-text"
            name="brd_text"
            rows="12"
            class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
            placeholder="Paste your BRD content here...

    Example:
    - Project Overview: E-commerce platform for retail customers
    - Key Features: Product catalog, shopping cart, payment integration
    - Expected Load: 10,000 concurrent users
    - Compliance: PCI-DSS for payment processing"
            value={@brd_text}
          >{@brd_text}</textarea>
          <p class="text-sm text-slate-500 mt-2">
            Minimum 100 characters recommended for meaningful analysis
          </p>
        </div>

    <!-- File Upload Section (Optional) -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-slate-700 mb-2">
            Or Upload a Document (Optional)
          </label>
          <div class="border-2 border-dashed border-slate-300 rounded-lg p-6 text-center hover:border-violet-400 transition-colors">
            <.icon name="hero-document-text" class="w-12 h-12 mx-auto text-slate-400 mb-2" />
            <p class="text-sm text-slate-600 mb-1">Drag & drop or click to upload</p>
            <p class="text-xs text-slate-500">Supports: .txt, .md, .pdf, .doc, .docx (max 10MB)</p>
          </div>
        </div>

    <!-- Submit Button -->
        <div class="flex items-center justify-end gap-4">
          <button
            type="submit"
            disabled={String.length(@brd_text) < 50}
            class="px-8 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none"
          >
            Continue to Elicitation
            <.icon name="hero-arrow-right" class="w-5 h-5 inline-block ml-2" />
          </button>
        </div>
      </form>
    </div>
    """
  end
end
