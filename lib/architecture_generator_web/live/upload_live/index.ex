defmodule ArchitectureGeneratorWeb.UploadLive.Index do
  use ArchitectureGeneratorWeb, :live_view

  alias ArchitectureGenerator.Uploads

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Upload Manager")
     |> assign(:uploads, Uploads.list_uploads())
     |> assign(:filter_project_id, nil)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Upload Manager")
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    upload = Uploads.get_upload!(id)
    {:ok, _} = Uploads.delete_upload(upload)

    {:noreply,
     socket
     |> put_flash(:info, "Upload deleted successfully")
     |> assign(:uploads, Uploads.list_uploads())}
  end

  @impl true
  def handle_event("filter", %{"project_id" => project_id}, socket) do
    uploads =
      if project_id == "" do
        Uploads.list_uploads()
      else
        Uploads.list_uploads_by_project(String.to_integer(project_id))
      end

    {:noreply,
     socket
     |> assign(:uploads, uploads)
     |> assign(:filter_project_id, project_id)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="min-h-screen bg-gradient-to-br from-violet-50 via-blue-50 to-cyan-50 py-12">
        <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <!-- Header -->
          <div class="mb-8">
            <h1 class="text-3xl font-bold text-slate-900 mb-2">Upload Manager</h1>
            <p class="text-slate-600">
              Manage all uploaded files with version history and S3 storage.
            </p>
          </div>
          
    <!-- Filters -->
          <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-6 mb-6">
            <form phx-change="filter" id="filter-form">
              <div class="flex items-center gap-4">
                <label for="project-filter" class="text-sm font-medium text-slate-700">
                  Filter by Project:
                </label>
                <select
                  id="project-filter"
                  name="project_id"
                  class="px-4 py-2 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                >
                  <option value="">All Projects</option>
                  <%= for upload <- @uploads |> Enum.map(& &1.project) |> Enum.uniq_by(& &1.id) do %>
                    <option value={upload.id} selected={@filter_project_id == to_string(upload.id)}>
                      {upload.name}
                    </option>
                  <% end %>
                </select>
              </div>
            </form>
          </div>
          
    <!-- Upload Cards -->
          <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <%= for upload <- @uploads do %>
              <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg hover:shadow-xl transition-shadow">
                <div class="p-6">
                  <!-- File Icon & Name -->
                  <div class="flex items-start gap-3 mb-4">
                    <div class="flex-shrink-0">
                      <.icon
                        name="hero-document-text"
                        class="w-12 h-12 text-violet-600"
                      />
                    </div>
                    <div class="flex-1 min-w-0">
                      <h3 class="text-lg font-semibold text-slate-900 truncate">
                        {upload.filename}
                      </h3>
                      <p class="text-sm text-slate-500">
                        {format_file_size(upload.size_bytes)}
                      </p>
                    </div>
                  </div>
                  
    <!-- Metadata -->
                  <div class="space-y-2 mb-4">
                    <div class="flex items-center gap-2 text-sm">
                      <span class="font-medium text-slate-700">Project:</span>
                      <span class="text-slate-600">{upload.project.name}</span>
                    </div>
                    <div class="flex items-center gap-2 text-sm">
                      <span class="font-medium text-slate-700">Version:</span>
                      <span class="text-slate-600">{upload.current_version}</span>
                    </div>
                    <div class="flex items-center gap-2 text-sm">
                      <span class="font-medium text-slate-700">Uploaded:</span>
                      <span class="text-slate-600">{format_date(upload.inserted_at)}</span>
                    </div>
                  </div>
                  
    <!-- Actions -->
                  <div class="flex items-center gap-2">
                    <.link
                      navigate={~p"/uploads/#{upload.id}"}
                      class="flex-1 px-4 py-2 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-lg font-semibold hover:shadow-lg hover:shadow-violet-500/30 transition-all text-center text-sm"
                    >
                      View Details
                    </.link>
                    <button
                      phx-click="delete"
                      phx-value-id={upload.id}
                      data-confirm="Are you sure you want to delete this upload and all its versions?"
                      class="px-4 py-2 bg-red-100 text-red-700 rounded-lg font-semibold hover:bg-red-200 transition-colors text-sm"
                    >
                      Delete
                    </button>
                  </div>
                </div>
              </div>
            <% end %>
          </div>

          <%= if @uploads == [] do %>
            <div class="text-center py-12">
              <.icon name="hero-folder-open" class="w-16 h-16 text-slate-400 mx-auto mb-4" />
              <p class="text-lg text-slate-600">No uploads found</p>
              <p class="text-sm text-slate-500 mt-2">
                Upload files from project pages to see them here
              </p>
            </div>
          <% end %>
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

  defp format_date(date) do
    Calendar.strftime(date, "%b %d, %Y")
  end
end
