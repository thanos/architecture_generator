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

      {:ok, _project} = Projects.complete_project(project, architectural_plan.id)

      Logger.info("Successfully generated LLM-based plan for project #{project_id}")


          case Projects.mark_project_error(project) do
            {:ok, _project} ->
              :ok

            {:error, error_changeset} ->
              Logger.error(
                "Failed to mark project #{project.id} as error: #{inspect(error_changeset.errors)}"
              )
          end

          {:error, changeset}

    rescue
      error ->
        Logger.error("Failed to generate plan for project #{project_id}: #{inspect(error)}")
        Projects.mark_project_error(project)
        {:error, error}
    end
  end

  defp generate_plan_with_llm(project) do

    context = """
    You are a senior software architect with extensive experience designing scalable,
    secure, and maintainable software systems.

    Based on the project information provided below, create a comprehensive Architectural Plan
    in Markdown format that includes:

    1. **Executive Summary** (2-3 paragraphs)
       - Project overview and key objectives
       - Critical architectural decisions
       - Expected outcomes

    2. **System Architecture Overview**
       - High-level architecture pattern (monolith, microservices, etc.)
       - Major components and their responsibilities
       - Data flow between components

    3. **Technology Stack Justification**
       - Why each chosen technology fits the requirements
       - Key trade-offs and considerations
       - How they work together

    4. **Scalability & Performance Strategy**
       - How the system will handle expected load
       - Caching strategies (CDN, application, database)
       - Database optimization approaches
       - Load balancing and auto-scaling plans

    5. **Security Architecture**
       - Authentication and authorization approach
       - Data encryption (in transit and at rest)
       - Compliance requirements implementation
       - API security measures

    6. **Integration Architecture**
       - Third-party service integration patterns
       - API design approach
       - Error handling and retry logic
       - Circuit breakers and fallbacks

    7. **Data Architecture**
       - Database schema design approach
       - Data modeling strategy
       - Backup and disaster recovery
       - Data retention and archival

    8. **Deployment Architecture**
       - CI/CD pipeline design
       - Environment strategy (dev/staging/prod)
       - Monitoring and observability
       - Logging and alerting

    9. **Development Workflow**
       - Recommended project structure
       - Testing strategy (unit, integration, e2e)
       - Code quality and review process

    10. **Risk Assessment & Mitigation**
        - Identified technical risks
        - Mitigation strategies
        - Contingency plans

    11. **Implementation Phases**
        - Phase 1: MVP/Core features with timeline
        - Phase 2: Enhanced features with timeline
        - Phase 3: Optimization and scaling with timeline

    12. **Success Metrics**
        - KPIs to measure system success
        - Performance benchmarks
        - User experience metrics

    Be specific and professional. Provide concrete recommendations based on industry
    best practices and the specific requirements provided. Use proper Markdown formatting
    with headers, lists, and code blocks where appropriate.

    The plan should be detailed enough for a development team to begin implementation
    with clear guidance on architectural decisions.

    # Business Requirements Document
    # Business Requirements Document
    #{project.brd_content || "No BRD provided"}

    # Technical Elicitation Data
    #{format_elicitation_data(project.elicitation_data)}

    # Technology Stack Configuration
    #{format_tech_stack(project.tech_stack_config)}
    """

    case LLMService.enhance_parsed_text(context, provider: :openai) do

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
