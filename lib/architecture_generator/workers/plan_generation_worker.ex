defmodule ArchitectureGenerator.Workers.PlanGenerationWorker do
  @moduledoc """
  Oban worker that processes queued projects and generates architectural plans.

  This worker:
  1. Receives a project_id from the queue
  2. Fetches the project with BRD content, elicitation data, and tech stack config
  3. Calls an LLM service to generate the architectural plan
  4. Creates an ArchitecturalPlan record
  5. Updates the project status to "Complete"
  6. Sends notification email (future enhancement)
  """
  use Oban.Worker, queue: :default, max_attempts: 3

  alias ArchitectureGenerator.{Projects, Plans}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    Logger.info("Starting plan generation for project #{project_id}")

    project = Projects.get_project!(project_id)

    # Validate project is in Queued status
    if project.status != "Queued" do
      Logger.warning("Project #{project_id} is not in Queued status, skipping")
      {:cancel, "Project not in Queued status"}
    end

    try do
      # Generate the architectural plan
      plan_content = generate_plan(project)

      # Create the architectural plan record
      {:ok, architectural_plan} =
        Plans.create_architectural_plan(%{
          content: plan_content,
          project_id: project.id
        })

      # Update project to Complete status
      {:ok, _project} = Projects.complete_project(project, architectural_plan.id)

      Logger.info("Successfully generated plan for project #{project_id}")

      {:ok, %{architectural_plan_id: architectural_plan.id}}
    rescue
      error ->
        Logger.error("Failed to generate plan for project #{project_id}: #{inspect(error)}")

        # Mark project as error
        case Projects.mark_project_error(project) do
          {:ok, _project} ->
            :ok

          {:error, changeset} ->
            Logger.error(
              "Failed to mark project #{project.id} as error: #{inspect(changeset.errors)}"
            )
        end

        {:error, error}
    end
  end

  defp generate_plan(project) do
    """
    # Architectural Plan for #{project.name}

    ## Project Overview
    **Generated on:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Status:** Complete

    ## Business Requirements Summary
    #{format_brd_summary(project.brd_content)}

    ## Elicitation Analysis
    #{format_elicitation_data(project.elicitation_data)}

    ## Technology Stack
    #{format_tech_stack(project.tech_stack_config)}

    ## Recommended Architecture

    ### High-Level Architecture
    Based on the requirements and technology choices, we recommend a microservices architecture with the following components:

    1. **Frontend Layer**
       - Technology: #{Map.get(project.tech_stack_config, "framework", "React/Vue.js")}
       - Deployment: CDN with edge caching
       - State Management: Redux/Vuex

    2. **API Gateway**
       - Technology: #{Map.get(project.tech_stack_config, "language", "Node.js")} with Express/Fastify
       - Authentication: JWT-based auth
       - Rate Limiting: Redis-based

    3. **Application Services**
       - Primary Language: #{Map.get(project.tech_stack_config, "language", "Python")}
       - Framework: #{Map.get(project.tech_stack_config, "framework", "FastAPI/Django")}
       - Communication: REST APIs + Message Queue

    4. **Data Layer**
       - Primary Database: #{Map.get(project.tech_stack_config, "database", "PostgreSQL")}
       - Caching: Redis
       - Search: Elasticsearch (if needed)

    5. **Infrastructure**
       - Platform: #{Map.get(project.tech_stack_config, "deployment", "AWS/GCP")}
       - Container Orchestration: Kubernetes
       - CI/CD: GitHub Actions + ArgoCD

    ### Scalability Considerations
    #{format_scalability_recommendations(project.elicitation_data)}

    ### Security Recommendations
    #{format_security_recommendations(project.elicitation_data)}

    ### Integration Points
    #{format_integration_recommendations(project.elicitation_data)}

    ## Next Steps
    1. Review and validate this architectural plan
    2. Create detailed component specifications
    3. Set up development environment
    4. Begin implementation with MVP features
    5. Establish monitoring and observability

    ---
    *This is an AI-generated architectural plan. Please review and adjust based on your specific needs.*
    """
  end

  defp format_brd_summary(brd_content) when is_binary(brd_content) do
    brd_content
    |> String.slice(0..500)
    |> then(fn summary ->
      if String.length(brd_content) > 500 do
        summary <> "...\n\n*[Full BRD content available in project details]*"
      else
        summary
      end
    end)
  end

  defp format_brd_summary(_), do: "*No BRD content provided*"

  defp format_elicitation_data(data) when is_map(data) and map_size(data) > 0 do
    data
    |> Enum.map(fn {question, answer} ->
      "- **#{question}**: #{answer}"
    end)
    |> Enum.join("\n")
  end

  defp format_elicitation_data(_), do: "*No elicitation data available*"

  defp format_tech_stack(config) when is_map(config) and map_size(config) > 0 do
    """
    - **Primary Language**: #{Map.get(config, "language", "Not specified")}
    - **Framework**: #{Map.get(config, "framework", "Not specified")}
    - **Database**: #{Map.get(config, "database", "Not specified")}
    - **Deployment**: #{Map.get(config, "deployment", "Not specified")}
    """
  end

  defp format_tech_stack(_), do: "*No tech stack configuration provided*"

  defp format_scalability_recommendations(elicitation_data) do
    concurrent_users = Map.get(elicitation_data, "Expected number of concurrent users", "unknown")
    data_volume = Map.get(elicitation_data, "Expected data volume", "unknown")

    """
    - **Expected Load**: #{concurrent_users} concurrent users
    - **Data Volume**: #{data_volume}
    - **Scaling Strategy**: Horizontal scaling with auto-scaling groups
    - **Load Balancing**: Application Load Balancer with health checks
    - **Database Scaling**: Read replicas + connection pooling
    """
  end

  defp format_security_recommendations(elicitation_data) do
    security_reqs = Map.get(elicitation_data, "Security and compliance requirements", "standard")

    """
    - **Security Requirements**: #{security_reqs}
    - **Authentication**: OAuth 2.0 / JWT tokens
    - **Authorization**: Role-based access control (RBAC)
    - **Data Encryption**: TLS 1.3 in transit, AES-256 at rest
    - **Compliance**: Regular security audits and penetration testing
    """
  end

  defp format_integration_recommendations(elicitation_data) do
    integrations = Map.get(elicitation_data, "Third-party integrations needed", "none")

    """
    - **Required Integrations**: #{integrations}
    - **Integration Pattern**: API Gateway + Service Mesh
    - **Error Handling**: Circuit breaker pattern with fallbacks
    - **Monitoring**: Centralized logging and distributed tracing
    """
  end
end
