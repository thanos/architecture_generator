defmodule ArchitectureGeneratorWeb.ProjectLive.ElicitationStep do
  use ArchitectureGeneratorWeb, :live_component

  alias ArchitectureGenerator.Projects

  @impl true
  def update(assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(:questions, get_elicitation_questions())
      |> assign(:answers, assigns.project.elicitation_data || %{})
      |> assign(:loading, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_answer", params, socket) do
    # Extract question_id from params - input names are like "answer_expected_users"
    # Find the key that starts with "answer_" (filter out Phoenix internal params like "_target")
    {question_id, answer} =
      params
      |> Enum.reject(fn {key, _value} -> String.starts_with?(key, "_") end)
      |> Enum.find(fn {key, _value} -> String.starts_with?(key, "answer_") end)
      |> case do
        nil -> {nil, ""}
        {key, value} -> {String.replace_prefix(key, "answer_", ""), value}
      end

    if question_id do
      answers = Map.put(socket.assigns.answers, question_id, answer)
      {:noreply, assign(socket, :answers, answers)}
    else
      # If we can't determine question_id, just return without error
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("submit_elicitation", _params, socket) do
    project = socket.assigns.project
    answers = socket.assigns.answers

    case Projects.save_elicitation_data(project, answers) do
      {:ok, _updated_project} ->
        send(self(), {:refresh_project, project.id})
        {:noreply, socket}

      {:error, _changeset} ->
        {:noreply, put_flash(socket, :error, "Failed to save elicitation data")}
    end
  end

  @impl true
  def handle_event("go_back", _params, socket) do
    project = socket.assigns.project

    case Projects.go_back_to_status(project, "Initial") do
      {:ok, _updated_project} ->
        send(self(), {:refresh_project, project.id})
        {:noreply, socket}

      {:error, _reason} ->
        {:noreply, put_flash(socket, :error, "Failed to go back to previous step")}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="bg-white/80 backdrop-blur-sm rounded-xl border border-violet-200 shadow-lg p-8">
      <h2 class="text-2xl font-bold text-slate-900 mb-6">
        Requirements Elicitation
      </h2>

      <p class="text-slate-600 mb-6">
        To generate a comprehensive architectural plan, please answer the following questions
        about your project requirements. These help clarify ambiguities in your BRD.
      </p>

      <form phx-submit="submit_elicitation" phx-target={@myself} id="elicitation-form">
        <div class="space-y-6">
          <%= for question <- @questions do %>
            <div class="bg-gradient-to-r from-violet-50 to-blue-50 rounded-lg p-6">
              <label
                for={"question-#{question.id}"}
                class="block text-sm font-bold text-slate-900 mb-3"
              >
                {question.text}
              </label>

              <%= if question.type == :text do %>
                <input
                  type="text"
                  id={"question-#{question.id}"}
                  name={"answer_#{question.id}"}
                  value={Map.get(@answers, question.id, "")}
                  phx-change="validate_answer"
                  phx-target={@myself}
                  class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  placeholder={question.placeholder}
                />
              <% end %>

              <%= if question.type == :textarea do %>
                <textarea
                  id={"question-#{question.id}"}
                  name={"answer_#{question.id}"}
                  rows="3"
                  phx-change="validate_answer"
                  phx-target={@myself}
                  class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 placeholder:text-slate-400 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                  placeholder={question.placeholder}
                >{Map.get(@answers, question.id, "")}</textarea>
              <% end %>

              <%= if question.type == :select do %>
                <select
                  id={"question-#{question.id}"}
                  name={"answer_#{question.id}"}
                  phx-change="validate_answer"
                  phx-target={@myself}
                  class="w-full px-4 py-3 rounded-lg bg-white text-slate-900 border-2 border-slate-200 focus:border-violet-400 focus:ring focus:ring-violet-200 focus:ring-opacity-50 transition-colors"
                >
                  <option value="">Select an option...</option>
                  <%= for option <- question.options do %>
                    <option value={option} selected={Map.get(@answers, question.id) == option}>
                      {option}
                    </option>
                  <% end %>
                </select>
              <% end %>

              <p class="text-xs text-slate-500 mt-2">{question.help_text}</p>
            </div>
          <% end %>
        </div>

        <div class="flex items-center justify-between gap-4 mt-8">
          <button
            type="button"
            phx-click="go_back"
            phx-target={@myself}
            class="px-6 py-3 bg-slate-200 text-slate-700 rounded-xl font-semibold hover:bg-slate-300 transition-all duration-300 flex items-center gap-2"
          >
            <.icon name="hero-arrow-left" class="w-5 h-5" />
            Back to Upload BRD
          </button>

          <button
            type="submit"
            disabled={map_size(@answers) < length(@questions)}
            class="px-8 py-3 bg-gradient-to-r from-violet-600 to-cyan-600 text-white rounded-xl font-semibold hover:shadow-xl hover:shadow-violet-500/30 transition-all duration-300 disabled:opacity-50 disabled:cursor-not-allowed disabled:hover:shadow-none"
          >
            Continue to Tech Stack Selection
            <.icon name="hero-arrow-right" class="w-5 h-5 inline-block ml-2" />
          </button>
        </div>
      </form>
    </div>
    """
  end

  defp get_elicitation_questions do
    [
      %{
        id: "expected_users",
        type: :text,
        text: "What is the expected number of concurrent users?",
        placeholder: "e.g., 10,000 concurrent users",
        help_text: "This helps us determine scalability requirements and infrastructure needs."
      },
      %{
        id: "performance_requirements",
        type: :textarea,
        text: "What are your performance requirements (latency, throughput, response time)?",
        placeholder: "e.g., 95th percentile response time < 200ms, 10,000 TPS",
        help_text: "Specify any SLAs, RTO/RPO, or performance targets."
      },
      %{
        id: "security_compliance",
        type: :select,
        text: "What security or compliance standards must be met?",
        options: ["None", "GDPR", "HIPAA", "PCI-DSS", "SOC 2", "ISO 27001", "Multiple standards"],
        help_text: "Select the primary compliance framework your application must adhere to."
      },
      %{
        id: "integration_requirements",
        type: :textarea,
        text: "What external systems or APIs will this integrate with?",
        placeholder: "e.g., Payment gateway (Stripe), CRM (Salesforce), Email service (SendGrid)",
        help_text: "List all third-party integrations and data sources."
      },
      %{
        id: "data_volume",
        type: :text,
        text: "What is the expected data volume and growth rate?",
        placeholder: "e.g., 1TB initial, growing 100GB/month",
        help_text: "This helps determine storage and database architecture."
      },
      %{
        id: "availability_requirements",
        type: :select,
        text: "What are your availability requirements?",
        options: [
          "99.9% (43.8 min downtime/month)",
          "99.95% (21.9 min downtime/month)",
          "99.99% (4.4 min downtime/month)",
          "99.999% (26 sec downtime/month)"
        ],
        help_text: "Select the minimum uptime percentage required."
      }
    ]
  end
end
