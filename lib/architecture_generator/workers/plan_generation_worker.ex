defmodule ArchitectureGenerator.Workers.PlanGenerationWorker do

  @moduledoc """
  Oban worker that processes queued projects and generates architectural plans using LLM.

  This worker:
  1. Receives a project_id from the queue
  2. Fetches the project with BRD content, elicitation data, and tech stack config
  3. Calls LLM service to generate the architectural plan
  4. Creates an ArchitecturalPlan record
  5. Updates the project status to "Complete"
  6. Sends notification email (future enhancement)
  """

  use Oban.Worker, queue: :default, max_attempts: 3

  alias ArchitectureGenerator.{Projects, Plans, LLMService}

  require Logger
  alias Phoenix.PubSub

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    Logger.info("Starting LLM-based plan generation for project #{project_id}")

    project = Projects.get_project!(project_id)

    if project.status != "Queued" do
      Logger.warning("Project #{project_id} is not in Queued status, skipping")
      {:cancel, "Project not in Queued status"}
    end

    try do
      plan_content = generate_plan_with_llm(project)


      {:ok, architectural_plan} =
        Plans.create_architectural_plan(%{
          content: plan_content,
          project_id: project.id
        })

      {:ok, updated_project} = Projects.complete_project(project, architectural_plan.id)

      Logger.info("Successfully generated LLM-based plan for project #{project_id}")

      # Broadcast to PubSub to notify any LiveView watching this project
      PubSub.broadcast(
        ArchitectureGenerator.PubSub,
        "project:#{project_id}",
        {:project_completed, updated_project}
      )

      :ok
    rescue
      error ->
        Logger.error("Failed to generate plan for project #{project_id}: #{inspect(error)}")
        {:ok, error_project} = Projects.mark_project_error(project)

        # Broadcast error to PubSub to notify any LiveView watching this project
        PubSub.broadcast(
          ArchitectureGenerator.PubSub,
          "project:#{project_id}",
          {:project_error, error_project}
        )

        {:error, error}
    end
  end

  defp generate_plan_with_llm(project) do
    # Build the full project context for the LLM
    context = """
    # Business Requirements Document
    #{project.brd_content || "No BRD provided"}

    # Technical Elicitation Data
    #{format_elicitation_data(project.elicitation_data)}

    # Technology Stack Configuration
    #{format_tech_stack(project.tech_stack_config)}
    """

    # Use the project's llm_provider, defaulting to :openai if not set
    provider =
      case project.llm_provider do
        nil -> :openai
        "" -> :openai
        provider when is_binary(provider) ->
          # Try to convert to atom, fallback to :openai if conversion fails
          try do
            String.to_existing_atom(provider)
          rescue
            ArgumentError -> :openai
          end
        provider when is_atom(provider) -> provider
        _ -> :openai
      end

    case LLMService.generate_architectural_plan(context, provider: provider) do
      {:ok, plan_content} ->
        plan_content

      {:error, reason} ->
        Logger.warning(
          "LLM generation failed for project #{project.id}, using fallback: #{inspect(reason)}"
        )

        generate_fallback_plan(project)
    end
  end


  defp generate_fallback_plan(project) do
    """
    # Architectural Plan for #{project.name}

    **Generated on:** #{DateTime.utc_now() |> DateTime.to_string()}
    **Status:** Complete (Fallback Mode - LLM unavailable)

    ## Executive Summary

    This architectural plan provides a foundation for implementing #{project.name}.
    Due to temporary LLM unavailability, this plan uses a standard template.
    Please review and enhance with project-specific details.

    ## Business Requirements Summary
    #{format_brd_summary(project.brd_content)}

    ## Technical Elicitation Analysis
    #{format_elicitation_data(project.elicitation_data)}

    ## Technology Stack
    #{format_tech_stack(project.tech_stack_config)}

    ## Recommended Architecture

    ### High-Level Architecture
    Based on the requirements and technology choices, we recommend a standard web application
    architecture with the following components:

    1. **Frontend Layer**

       - Technology: #{Map.get(project.tech_stack_config, "web_framework", "Modern Web Framework")}

       - Deployment: CDN with edge caching
       - State Management: Context-based or global state

    2. **API Gateway**

       - Technology: #{Map.get(project.tech_stack_config, "primary_language", "Selected Language")} with framework
       - Authentication: JWT-based or session-based auth
       - Rate Limiting: Token bucket algorithm

    3. **Application Services**
       - Primary Language: #{Map.get(project.tech_stack_config, "primary_language", "Selected Language")}
       - Framework: #{Map.get(project.tech_stack_config, "web_framework", "Selected Framework")}
       - Communication: REST APIs + Background Jobs

    4. **Data Layer**
       - Primary Database: #{Map.get(project.tech_stack_config, "database_system", "Selected Database")}
       - Caching: Redis or in-memory cache
       - Search: Full-text search if needed

    5. **Infrastructure**
       - Platform: #{Map.get(project.tech_stack_config, "deployment_env", "Selected Platform")}
       - Container Orchestration: Docker-based deployment
       - CI/CD: Automated pipeline with testing gates

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
    *This is a fallback architectural plan. Consider regenerating with LLM for more detailed analysis.*
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
    - **Primary Language**: #{Map.get(config, "primary_language", "Not specified")}
    - **Framework**: #{Map.get(config, "web_framework", "Not specified")}
    - **Database**: #{Map.get(config, "database_system", "Not specified")}
    - **Deployment**: #{Map.get(config, "deployment_env", "Not specified")}
    """
  end

  defp format_tech_stack(_), do: "*No tech stack configuration provided*"

  defp format_scalability_recommendations(elicitation_data) do
    concurrent_users =

      Map.get(elicitation_data, "expected_users", "unknown")

    data_volume = Map.get(elicitation_data, "data_volume", "unknown")


    """
    - **Expected Load**: #{concurrent_users}
    - **Data Volume**: #{data_volume}
    - **Scaling Strategy**: Horizontal scaling with auto-scaling groups
    - **Load Balancing**: Application Load Balancer with health checks
    - **Database Scaling**: Read replicas + connection pooling
    """
  end

  defp format_security_recommendations(elicitation_data) do
    security_reqs =

      Map.get(elicitation_data, "security_compliance", "standard")


    """
    - **Security Requirements**: #{security_reqs}
    - **Authentication**: OAuth 2.0 / JWT tokens
    - **Authorization**: Role-based access control (RBAC)
    - **Data Encryption**: TLS 1.3 in transit, AES-256 at rest
    - **Compliance**: Regular security audits and penetration testing
    """
  end

  defp format_integration_recommendations(elicitation_data) do
    integrations =

      Map.get(elicitation_data, "integration_requirements", "none")
    """
    - **Required Integrations**: #{integrations}
    - **Integration Pattern**: API Gateway + Service Mesh
    - **Error Handling**: Circuit breaker pattern with fallbacks
    - **Monitoring**: Centralized logging and distributed tracing
    """
  end

  defp extract_elicitation_value(data, key_variants) when is_map(data) do
    Enum.find_value(key_variants, "not specified", fn key ->
      Map.get(data, key)
    end)
  end

  defp extract_elicitation_value(_, _), do: "not specified"
end
