defmodule ArchitectureGeneratorWeb.UploadLive.Show do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Uploads

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    upload = Uploads.get_upload!(id)

    {:ok,
     socket
     |> assign(:page_title, "Upload Details")
     |> assign(:upload, upload)
     |> assign(:editing, false)
     |> allow_upload(:new_version,
       accept: :any,
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true
     )}
  end

  @impl true
  def handle_params(_params, _url, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("toggle_edit", _params, socket) do
    {:noreply, assign(socket, :editing, !socket.assigns.editing)}
  end

  @impl true
  def handle_event("validate_upload", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("cancel_upload", %{"ref" => ref}, socket) do
    {:noreply, cancel_upload(socket, :new_version, ref)}
  end

  @impl true
  def handle_event("submit_new_version", _params, socket) do
    upload = socket.assigns.upload

    uploaded_files =
      consume_uploaded_entries(socket, :new_version, fn %{path: path}, entry ->
        case Uploads.update_upload(upload, path, %{
               filename: entry.client_name,
               content_type: entry.client_type,
               size_bytes: entry.client_size
             }) do
          {:ok, updated_upload} ->
            {:ok, updated_upload}

          {:error, _reason} ->
            {:postpone, :error}
        end
      end)

    case uploaded_files do
      [updated_upload | _] ->
        {:noreply,
         socket
         |> put_flash(:info, "New version uploaded successfully")
         |> assign(:upload, updated_upload)
         |> assign(:editing, false)}

      [] ->
        {:noreply, put_flash(socket, :error, "Failed to upload new version")}
    end
  end

  @impl true
  def handle_event("delete_version", %{"version_id" => version_id}, socket) do
    # For now, we'll just show a message - actual implementation would need restore logic
    {:noreply,
     put_flash(
       socket,
       :info,
       "Version deletion not yet implemented - versions are kept for audit trail"
     )}
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
              navigate={~p"/uploads"}
              class="inline-flex items-center gap-2 text-slate-600 hover:text-slate-900 font-medium transition-colors"
            >
              <.icon name="hero-arrow-left" class="w-5 h-5" /> Back to Uploads
            </.link>
          </div>
          
    <!-- Upload Details Card -->
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8 mb-6">
            <div class="flex items-start justify-between mb-6">
              <div class="flex items-start gap-4">
                <div class="p-3 bg-gradient-to-br from-violet-100 to-cyan-100 rounded-xl">
                  <.icon name="hero-document-text" class="w-12 h-12 text-violet-600" />
                </div>
                <div>
                  <h1 class="text-2xl font-bold text-slate-900 mb-2">
                    {@upload.filename}
                  </h1>
                  <div class="flex items-center gap-4 text-sm text-slate-600">
                    <span class="flex items-center gap-1">
                      <.icon name="hero-folder" class="w-4 h-4" />
                      {@upload.project.name}
                    </span>
                    <span class="flex items-center gap-1">
                      <.icon name="hero-document-duplicate" class="w-4 h-4" />
                      Version {@upload.current_version}
                    </span>
                    <span>{format_file_size(@upload.size_bytes)}</span>
                  </div>
                </div>
              </div>
              
    <!-- Action Buttons -->
              <div class="flex items-center gap-2">
                <button
                  phx-click="toggle_edit"
                  class="px-4 py-2 bg-violet-100 text-violet-700 rounded-lg font-semibold hover:bg-violet-200 transition-colors"
                >
                  <%= if @editing do %>
                    Cancel
                  <% else %>
                    Upload New Version
                  <% end %>
                </button>
                <a
                  href={Uploads.get_download_url(@upload)}
                  class="px-4 py-2 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-lg font-semibold hover:shadow-lg hover:shadow-violet-500/30 transition-all"
                  download
                >
                  Download Current
                </a>
              </div>
            </div>
            
    <!-- Metadata Grid -->
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4 p-4 bg-slate-50 rounded-lg">
              <div>
                <p class="text-xs text-slate-500 mb-1">Content Type</p>
                <p class="text-sm font-medium text-slate-900">{@upload.content_type || "Unknown"}</p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">S3 Bucket</p>
                <p class="text-sm font-medium text-slate-900">{@upload.s3_bucket}</p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">Created</p>
                <p class="text-sm font-medium text-slate-900">
                  {Calendar.strftime(@upload.inserted_at, "%b %d, %Y")}
                </p>
              </div>
              <div>
                <p class="text-xs text-slate-500 mb-1">Last Updated</p>
                <p class="text-sm font-medium text-slate-900">
                  {Calendar.strftime(@upload.updated_at, "%b %d, %Y")}
                </p>
              </div>
            </div>
          </div>
          
    <!-- Upload New Version Form -->
          <%= if @editing do %>
            <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8 mb-6">
              <h2 class="text-xl font-bold text-slate-900 mb-4">Upload New Version</h2>
              <p class="text-slate-600 mb-6">
                Upload a new file to create version {@upload.current_version + 1}. Previous versions will be preserved.
              </p>

              <form phx-submit="submit_new_version" id="new-version-form">
                <div
                  class="border-2 border-dashed border-slate-300 rounded-lg p-8 text-center hover:border-violet-400 transition-colors"
                  phx-drop-target={@uploads.new_version.ref}
                >
                  <.icon name="hero-arrow-up-tray" class="w-12 h-12 mx-auto text-slate-400 mb-4" />

                  <label for={@uploads.new_version.ref} class="cursor-pointer">
                    <p class="text-sm text-slate-600 mb-1">
                      Drag & drop or
                      <span class="text-violet-600 font-semibold hover:text-violet-700">
                        click to upload
                      </span>
                    </p>
                    <p class="text-xs text-slate-500">Max 10MB</p>
                  </label>

                  <.live_file_input upload={@uploads.new_version} class="hidden" />
                </div>
                
    <!-- Upload Progress -->
                <%= for entry <- @uploads.new_version.entries do %>
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
                        class="text-slate-400 hover:text-red-600 transition-colors"
                      >
                        <.icon name="hero-x-mark" class="w-5 h-5" />
                      </button>
                    </div>

                    <div class="w-full bg-slate-200 rounded-full h-2">
                      <div
                        class="bg-gradient-to-r from-violet-600 to-cyan-600 h-2 rounded-full transition-all"
                        style={"width: #{entry.progress}%"}
                      >
                      </div>
                    </div>

                    <%= for err <- upload_errors(@uploads.new_version, entry) do %>
                      <p class="text-xs text-red-600 mt-2">{error_to_string(err)}</p>
                    <% end %>
                  </div>
                <% end %>
              </form>
            </div>
          <% end %>
          
    <!-- Version History -->
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
            <h2 class="text-xl font-bold text-slate-900 mb-6">Version History</h2>

            <div class="space-y-4">
              <%= for version <- @upload.versions do %>
                <div class="flex items-center justify-between p-4 bg-slate-50 rounded-lg hover:bg-slate-100 transition-colors">
                  <div class="flex items-center gap-4">
                    <div class="flex items-center justify-center w-10 h-10 bg-violet-100 text-violet-700 rounded-full font-bold">
                      v{version.version_number}
                    </div>
                    <div>
                      <p class="font-medium text-slate-900">{version.filename}</p>
                      <p class="text-sm text-slate-500">
                        {format_file_size(version.size_bytes)} • {Calendar.strftime(
                          version.inserted_at,
                          "%b %d, %Y at %I:%M %p"
                        )}
                      </p>
                    </div>
                  </div>

                  <div class="flex items-center gap-2">
                    <%= if version.version_number == @upload.current_version do %>
                      <span class="px-3 py-1 bg-green-100 text-green-700 text-xs font-semibold rounded-full">
                        Current
                      </span>
                    <% end %>
                    <a
                      href={Uploads.get_version_download_url(version)}
                      class="px-4 py-2 bg-slate-200 text-slate-700 rounded-lg font-semibold hover:bg-slate-300 transition-colors text-sm"
                      download
                    >
                      Download
                    </a>
                  </div>
                </div>
              <% end %>
            </div>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  defp format_file_size(bytes) when is_integer(bytes) do
    cond do
      bytes >= 1_000_000_000 -> "#{Float.round(bytes / 1_000_000_000, 2)} GB"
      bytes >= 1_000_000 -> "#{Float.round(bytes / 1_000_000, 2)} MB"
      bytes >= 1_000 -> "#{Float.round(bytes / 1_000, 2)} KB"
      true -> "#{bytes} B"
    end
  end

  defp format_file_size(_), do: "Unknown"

  defp error_to_string(:too_large), do: "File is too large"
  defp error_to_string(:not_accepted), do: "File type not accepted"
  defp error_to_string(:external_client_failure), do: "Upload failed"
end
