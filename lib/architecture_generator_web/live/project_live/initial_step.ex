defmodule ArchitectureGeneratorWeb.ProjectLive.InitialStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.{Projects, Uploads}

  def update(assigns, socket) do
    # Handle full updates (when project is provided) and partial updates (when only specific fields are updated)
    socket =
      if Map.has_key?(assigns, :project) do
        # Full update - project data is provided
        # Always reload project from database to get the latest saved values
        # This ensures that any values saved by validate_form are loaded
        project = Projects.get_project!(assigns.project.id)

        socket
        |> assign(:project, project)
        |> assign(:id, assigns.id)
        |> assign(:brd_text, project.brd_content || "")
        |> assign(:processing_mode, project.processing_mode || "parse_only")
        |> assign(:llm_provider, project.llm_provider || "openai")
        |> assign(:parsing_status, nil)
        |> assign(:parsed_content_preview, nil)
        |> allow_upload(:brd_file,
          accept: ~w(.txt .md .pdf .doc .docx),
          max_entries: 1,
          max_file_size: 10_000_000,
          auto_upload: true
        )
      else
        # Partial update - preserve existing state, only update id if provided
        socket
        |> then(fn s ->
          if Map.has_key?(assigns, :id), do: assign(s, :id, assigns.id), else: s
        end)
      end
      |> then(fn s ->
        # Handle parsing_status updates
        if Map.has_key?(assigns, :parsing_status) do
          assign(s, :parsing_status, assigns.parsing_status)
        else
          # Ensure parsing_status is always initialized
          assign_new(s, :parsing_status, fn -> nil end)
        end
      end)
      |> then(fn s ->
        # Handle parsed_content_preview updates
        if Map.has_key?(assigns, :parsed_content_preview) do
          assign(s, :parsed_content_preview, assigns.parsed_content_preview)
        else
          # Ensure parsed_content_preview is always initialized
          assign_new(s, :parsed_content_preview, fn -> nil end)
        end
      end)

    {:ok, socket}
  end

  def handle_event("validate_form", params, socket) do
    # Save ALL form values together whenever ANY field changes
    # This ensures all settings persist regardless of which field was changed
    project = socket.assigns.project

    # Get values from params or fall back to socket assigns
    brd_text = Map.get(params, "brd_text", socket.assigns.brd_text || "")
    processing_mode = Map.get(params, "processing_mode", socket.assigns.processing_mode || "parse_only")
    llm_provider = Map.get(params, "llm_provider", socket.assigns.llm_provider || "openai")

    # Save all values together to database
    Projects.save_draft_brd_inputs(project, %{
      brd_content: brd_text,
      processing_mode: processing_mode,
      llm_provider: llm_provider
    })

    {:noreply,
     socket
     |> assign(:brd_text, brd_text)
     |> assign(:processing_mode, processing_mode)
     |> assign(:llm_provider, llm_provider)}
  end

  # Keep the old handler names for backward compatibility, but route to validate_form
  def handle_event("validate_brd", params, socket) do
    handle_event("validate_form", params, socket)
  end

  def handle_event("validate_processing_mode", params, socket) do
    handle_event("validate_form", params, socket)
  end

  def handle_event("validate_upload", _params, socket) do
    # Save ALL form values when a file is selected/uploaded
    # to ensure they persist even if the component gets re-rendered
    project = socket.assigns.project
    brd_text = socket.assigns.brd_text || ""
    processing_mode = socket.assigns.processing_mode || "parse_only"
    llm_provider = socket.assigns.llm_provider || "openai"

    # Save all values together
    Projects.save_draft_brd_inputs(project, %{
      brd_content: brd_text,
      processing_mode: processing_mode,
      llm_provider: llm_provider
    })

    {:noreply, socket}
  end

  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :brd_file, ref)}
  end

  def handle_event("submit_brd", %{"brd_text" => brd_text}, socket) do
    project = socket.assigns.project
    processing_mode = socket.assigns.processing_mode
    llm_provider = socket.assigns.llm_provider

    # Handle file upload if present - store in S3 via Uploads context
    result =
      consume_uploaded_entries(socket, :brd_file, fn %{path: path}, entry ->
        # Set parsing status
        send(self(), {:update_parsing_status, "Processing #{entry.client_name}..."})

        # Ensure processing_mode and llm_provider are saved before processing the file
        # This ensures they persist even if the component gets re-rendered
        Projects.save_draft_brd_inputs(project, %{
          processing_mode: processing_mode,
          llm_provider: llm_provider
        })

        # Reload project to get the latest values
        project = Projects.get_project!(project.id)

        # Create upload record and store file in S3
        case Uploads.create_upload(
               %{
                 project_id: project.id,
                 filename: entry.client_name,
                 content_type: entry.client_type,
                 size_bytes: entry.client_size,
                 uploaded_by: project.user_email,
                 processing_mode: processing_mode,
                 llm_provider: llm_provider
               },
               path
             ) do
          {:ok, upload, parsed_content} ->
            # Notify parsing complete
            if parsed_content do
              send(
                self(),
                {:update_parsing_status, "✅ Successfully processed #{entry.client_name}"}
              )

              send(self(), {:show_content_preview, String.slice(parsed_content, 0..500)})
            else
              send(self(), {:update_parsing_status, "⚠️ Could not extract text from file"})
            end

            {:ok, {upload, parsed_content}}

          {:error, reason} ->
            send(self(), {:update_parsing_status, "❌ Upload failed: #{inspect(reason)}"})
            {:postpone, reason}
        end
      end)

    # Determine final BRD content
    final_brd_content =
      case result do
        [{_upload, parsed_content} | _] when is_binary(parsed_content) ->
          # If file was uploaded and processed successfully, use parsed/LLM content
          parsed_content

        [{_upload, nil} | _] ->
          # File uploaded but processing failed, try reading raw content
          case result do
            [{_upload, _} | _] ->
              # Fallback to text area content if processing failed
              if String.length(brd_text) > 0,
                do: brd_text,
                else: "File uploaded but processing failed"

            _ ->
              brd_text
          end

        _ ->
          # Otherwise use text area content
          brd_text
      end

    # Update project with BRD content
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

      <form phx-change="validate_form" phx-submit="submit_brd" phx-target={@myself} id="brd-form">
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

    <!-- Processing Mode Selection -->
        <div class="mb-6 bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
          <h3 class="text-lg font-bold text-slate-900 mb-4">
            🤖 AI Processing Options
          </h3>

          <div class="space-y-4" phx-change="validate_form" phx-target={@myself}>
            <!-- Parse Only -->
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="radio"
                name="processing_mode"
                value="parse_only"
                checked={@processing_mode == "parse_only"}
                class="mt-1 w-4 h-4 text-violet-600 border-slate-300 focus:ring-violet-500"
              />
              <div>
                <p class="font-semibold text-slate-900">Parse Document Only</p>
                <p class="text-sm text-slate-600">
                  Extract text from your document without AI enhancement (fastest, free)
                </p>
              </div>
            </label>

    <!-- LLM Parsed -->
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="radio"
                name="processing_mode"
                value="llm_parsed"
                checked={@processing_mode == "llm_parsed"}
                class="mt-1 w-4 h-4 text-violet-600 border-slate-300 focus:ring-violet-500"
              />
              <div>
                <p class="font-semibold text-slate-900">Parse + AI Enhancement</p>
                <p class="text-sm text-slate-600">
                  Extract text, then use AI to create a professional, standardized BRD
                </p>
              </div>
            </label>

    <!-- LLM Raw -->
            <label class="flex items-start gap-3 cursor-pointer">
              <input
                type="radio"
                name="processing_mode"
                value="llm_raw"
                checked={@processing_mode == "llm_raw"}
                class="mt-1 w-4 h-4 text-violet-600 border-slate-300 focus:ring-violet-500"
              />
              <div>
                <p class="font-semibold text-slate-900">Direct AI Conversion</p>
                <p class="text-sm text-slate-600">
                  Send raw document to AI for complete BRD generation (best for rough notes)
                </p>
              </div>
            </label>

    <!-- LLM Provider Selection (only show if AI mode selected) -->
            <%= if @processing_mode in ["llm_parsed", "llm_raw"] do %>
              <div class="mt-4 pl-7">
                <label for="llm-provider" class="block text-sm font-medium text-slate-700 mb-2">
                  AI Provider
                </label>
                <select
                  id="llm-provider"
                  name="llm_provider"
                  class="w-full max-w-xs px-4 py-2 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                >
                  <option value="openai" selected={@llm_provider == "openai"}>
                    OpenAI (GPT-4o-mini)
                  </option>
                </select>
                <p class="text-xs text-slate-500 mt-1">
                  Requires OPENAI_API_KEY environment variable
                </p>
              </div>
            <% end %>
          </div>
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
              <p class="text-xs text-slate-500">
                Supports: .txt, .md, .pdf, .doc, .docx (max 10MB)
              </p>
              <p class="text-xs text-violet-600 font-semibold mt-1">
                ✨ Automatic text extraction from PDF and Word files
              </p>
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

    <!-- Parsing Status -->
          <%= if @parsing_status do %>
            <div class="mt-4 p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <div class="flex items-center gap-2">
                <.icon name="hero-document-magnifying-glass" class="w-5 h-5 text-blue-600" />
                <span class="text-sm font-medium text-blue-900">{@parsing_status}</span>
              </div>
            </div>
          <% end %>

    <!-- Parsed Content Preview -->
          <%= if @parsed_content_preview do %>
            <div class="mt-4 p-4 bg-green-50 border border-green-200 rounded-lg">
              <p class="text-sm font-semibold text-green-900 mb-2">
                📄 Content Preview (first 500 characters):
              </p>
              <p class="text-xs text-green-800 font-mono whitespace-pre-wrap">
                {@parsed_content_preview}...
              </p>
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
