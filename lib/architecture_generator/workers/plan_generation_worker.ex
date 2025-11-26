defmodule ArchitectureGenerator.Workers.PlanGenerationWorker do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias ArchitectureGenerator.{Projects, Plans}

  require Logger

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"project_id" => project_id}}) do
    Logger.info("Starting plan generation for project #{project_id}")

    project = Projects.get_project!(project_id)

    if project.status != "Queued" do
      Logger.warning("Project #{project_id} is not in Queued status, skipping")
      {:cancel, "Project not in Queued status"}
    end

    try do
      plan_content = generate_plan_with_llm(project)

      case Plans.create_architectural_plan(%{
             content: plan_content,
             project_id: project.id
           }) do
        {:ok, architectural_plan} ->
          case Projects.complete_project(project, architectural_plan.id) do
            {:ok, _project} ->
              Logger.info("Successfully generated plan for project #{project_id}")
              {:ok, %{architectural_plan_id: architectural_plan.id}}

            {:error, changeset} ->
              Logger.error(
                "Failed to mark project #{project.id} as complete: #{inspect(changeset.errors)}"
              )

              {:error, changeset}
          end

        {:error, changeset} ->
          Logger.error(
            "Failed to create architectural plan for project #{project.id}: #{inspect(changeset.errors)}"
          )

          case Projects.mark_project_error(project) do
            {:ok, _project} ->
              :ok

            {:error, error_changeset} ->
              Logger.error(
                "Failed to mark project #{project.id} as error: #{inspect(error_changeset.errors)}"
              )
          end

          {:error, changeset}
      end
    rescue
      error ->
        Logger.error("Failed to generate plan for project #{project_id}: #{inspect(error)}")

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

  defp generate_plan_with_llm(project) do
    prompt = build_architectural_prompt(project)

    case ReqLLM.generate_text("openai:gpt-4o-mini", prompt) do
      {:ok, plan_content} ->
        plan_content

      {:error, reason} ->
        Logger.warning(
          "LLM generation failed for project #{project.id}: #{inspect(reason)}. Falling back to template."
        )

        generate_fallback_plan(project)
    end
  end

  defp build_architectural_prompt(project) do
    """
    You are an expert software architect. Generate a comprehensive architectural plan based on the following information:

    ## Business Requirements Document
    #{project.brd_content || "No BRD provided"}

    ## Elicitation Data
    #{format_elicitation_for_prompt(project.elicitation_data)}

    ## Technology Stack
    #{format_tech_stack_for_prompt(project.tech_stack_config)}

    Please provide a detailed architectural plan with the following sections:

    1. **Executive Summary** - High-level overview of the architecture
    2. **Business Context** - Understanding of business requirements and goals
    3. **Functional Requirements** - Key features and capabilities
    4. **Non-Functional Requirements** - Performance, scalability, security considerations
    5. **Architecture Overview** - High-level system design and component interaction
    6. **Component Design** - Detailed breakdown of major system components
    7. **Data Model** - Database schema and data flow
    8. **API Design** - Key endpoints and integration points
    9. **Security Architecture** - Authentication, authorization, and data protection
    10. **Scalability Strategy** - How the system will handle growth
    11. **Integration Requirements** - Third-party services and external systems
    12. **Success Metrics** - How to measure architectural effectiveness

    Format the response in clear Markdown with proper headings and sections.
    """
  end

  defp format_elicitation_for_prompt(data) when is_map(data) and map_size(data) > 0 do
    data
    |> Enum.map(fn {question, answer} ->
      "- **#{question}**: #{answer}"
    end)
    |> Enum.join("\n")
  end

  defp format_elicitation_for_prompt(_), do: "*No elicitation data provided*"

  defp format_tech_stack_for_prompt(config) when is_map(config) and map_size(config) > 0 do
    """
    - **Primary Language**: #{Map.get(config, "primary_language", "Not specified")}
    - **Framework**: #{Map.get(config, "web_framework", "Not specified")}
    - **Database**: #{Map.get(config, "database_system", "Not specified")}
    - **Deployment**: #{Map.get(config, "deployment_env", "Not specified")}
    """
  end

  defp format_tech_stack_for_prompt(_), do: "*No tech stack configuration provided*"

  defp generate_fallback_plan(project) do
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
       - Technology: #{Map.get(project.tech_stack_config, "web_framework", "React/Vue.js")}
       - Deployment: CDN with edge caching
       - State Management: Redux/Vuex

    2. **API Gateway**
       - Technology: #{Map.get(project.tech_stack_config, "primary_language", "Node.js")} with Express/Fastify
       - Authentication: JWT-based auth
       - Rate Limiting: Redis-based

    3. **Application Services**
       - Primary Language: #{Map.get(project.tech_stack_config, "primary_language", "Python")}
       - Framework: #{Map.get(project.tech_stack_config, "web_framework", "FastAPI/Django")}
       - Communication: REST APIs + Message Queue

    4. **Data Layer**
       - Primary Database: #{Map.get(project.tech_stack_config, "database_system", "PostgreSQL")}
       - Caching: Redis
       - Search: Elasticsearch (if needed)

    5. **Infrastructure**
       - Platform: #{Map.get(project.tech_stack_config, "deployment_env", "AWS/GCP")}
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
    - **Primary Language**: #{Map.get(config, "primary_language", "Not specified")}
    - **Framework**: #{Map.get(config, "web_framework", "Not specified")}
    - **Database**: #{Map.get(config, "database_system", "Not specified")}
    - **Deployment**: #{Map.get(config, "deployment_env", "Not specified")}
    """
  end

  defp format_tech_stack(_), do: "*No tech stack configuration provided*"

  defp format_scalability_recommendations(elicitation_data) do
    concurrent_users =
      extract_elicitation_value(elicitation_data, [
        "Expected number of concurrent users",
        "expected_users",
        "concurrent_users",
        "Expected concurrent users"
      ])

    data_volume =
      extract_elicitation_value(elicitation_data, [
        "Expected data volume",
        "data_volume",
        "Expected data size"
      ])

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
      extract_elicitation_value(elicitation_data, [
        "Security and compliance requirements",
        "security_compliance",
        "security_requirements",
        "Security requirements"
      ])

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
      extract_elicitation_value(elicitation_data, [
        "Third-party integrations needed",
        "integration_requirements",
        "integrations",
        "Required integrations"
      ])

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
