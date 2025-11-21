defmodule ArchitectureGeneratorWeb.ProjectLive.InitialStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.Projects

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:brd_text, assigns.project.brd_content || "")
     |> allow_upload(:brd_file,
       accept: ~w(.txt .md .pdf .doc .docx),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_event("validate_brd", %{"brd_text" => brd_text}, socket) do
    {:noreply, assign(socket, :brd_text, brd_text)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :brd_file, ref)}
  end

  @impl true
  def handle_event("submit_brd", %{"brd_text" => brd_text}, socket) do
    project = socket.assigns.project

    # Handle file upload if present
    uploaded_files =
      consume_uploaded_entries(socket, :brd_file, fn %{path: path}, _entry ->
        # Read file content
        content = File.read!(path)
        {:ok, content}
      end)

    # Combine text input with uploaded file content
    final_brd_content =
      case uploaded_files do
        [file_content | _] when byte_size(file_content) > 0 ->
          # If file was uploaded, use file content
          file_content

        _ ->
          # Otherwise use text area content
          brd_text
      end

    case Projects.update_brd_content(project, %{brd_content: final_brd_content}) do
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
        
    <!-- File Upload Section -->
        <div class="mb-6">
          <label class="block text-sm font-medium text-slate-700 mb-2">
            Or Upload a Document
          </label>

          <div
            class="border-2 border-dashed border-slate-300 rounded-lg p-6 text-center hover:border-violet-400 transition-colors"
            phx-drop-target={@uploads.brd_file.ref}
          >
            <.icon name="hero-document-text" class="w-12 h-12 mx-auto text-slate-400 mb-2" />

            <label for={@uploads.brd_file.ref} class="cursor-pointer">
              <p class="text-sm text-slate-600 mb-1">
                Drag & drop or
                <span class="text-violet-600 font-semibold hover:text-violet-700">
                  click to upload
                </span>
              </p>
              <p class="text-xs text-slate-500">Supports: .txt, .md, .pdf, .doc, .docx (max 10MB)</p>
            </label>

            <.live_file_input upload={@uploads.brd_file} class="hidden" />
          </div>
          
    <!-- Upload Progress & Preview -->
          <%= for entry <- @uploads.brd_file.entries do %>
            <div class="mt-4 p-4 bg-violet-50 border border-violet-200 rounded-lg">
              <div class="flex items-center justify-between mb-2">
                <div class="flex items-center gap-2">
                  <.icon name="hero-document-text" class="w-5 h-5 text-violet-600" />
                  <span class="text-sm font-medium text-slate-900">{entry.client_name}</span>
                </div>
                <button
                  type="button"
                  phx-click="cancel_upload"
                  phx-value-ref={entry.ref}
                  phx-target={@myself}
                  class="text-slate-400 hover:text-red-600 transition-colors"
                  aria-label="Cancel upload"
                >
                  <.icon name="hero-x-mark" class="w-5 h-5" />
                </button>
              </div>
              
    <!-- Progress Bar -->
              <div class="w-full bg-slate-200 rounded-full h-2 overflow-hidden">
                <div
                  class="bg-gradient-to-r from-violet-600 to-cyan-600 h-2 transition-all duration-300"
                  style={"width: #{entry.progress}%"}
                >
                </div>
              </div>
              <p class="text-xs text-slate-600 mt-1">{entry.progress}% uploaded</p>
              
    <!-- Upload Errors -->
              <%= for err <- upload_errors(@uploads.brd_file, entry) do %>
                <p class="text-xs text-red-600 mt-2 flex items-center gap-1">
                  <.icon name="hero-exclamation-circle" class="w-4 h-4" />
                  {error_to_string(err)}
                </p>
              <% end %>
            </div>
          <% end %>
          
    <!-- General Upload Errors -->
          <%= for err <- upload_errors(@uploads.brd_file) do %>
            <p class="text-sm text-red-600 mt-2 flex items-center gap-1">
              <.icon name="hero-exclamation-circle" class="w-4 h-4" />
              {error_to_string(err)}
            </p>
          <% end %>
        </div>
        
    <!-- Submit Button -->
        <div class="flex items-center justify-end gap-4">
          <button
            type="submit"
            disabled={String.length(@brd_text) < 50 && @uploads.brd_file.entries == []}
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

  # Convert upload errors to human-readable strings
  defp error_to_string(:too_large), do: "File is too large (max 10MB)"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:too_many_files), do: "Only one file allowed"
  defp error_to_string(:external_client_failure), do: "Upload failed, please try again"
end
