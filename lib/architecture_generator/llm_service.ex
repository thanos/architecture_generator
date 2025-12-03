defmodule ArchitectureGenerator.LLMService do
  @moduledoc """
  Service for interacting with LLM providers using ReqLLM to generate and enhance BRDs.
  """

  require Logger
  alias ArchitectureGenerator.Artifacts

  @doc """
  Converts a raw document to a canonical best-practice BRD using an LLM.

  Takes the raw file content (binary) and sends it to the LLM with instructions
  to convert it into a well-structured Business Requirements Document.

  Returns {:ok, brd_content} or {:error, reason}
  """
  def convert_document_to_brd(file_content, filename, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    model_spec = build_model_spec(provider)

    prompt = build_conversion_prompt(filename)

    user_content =
      if is_binary(file_content), do: inspect(file_content, limit: 5000), else: file_content

    messages = [
      %{role: "system", content: prompt},
      %{role: "user", content: user_content}
    ]

    # Pass artifact metadata to call_llm
    artifact_opts = [
      project_id: Keyword.get(opts, :project_id),
      type: "doc",
      category: "Function Requirement Document",
      title: "BRD Conversion: #{filename}"
    ]

    call_llm(model_spec, messages, artifact_opts)
  end

  @doc """
  Enhances already-parsed text content with LLM to create a canonical BRD.

  Takes parsed text and sends it to the LLM with instructions to enhance,
  structure, and fill in missing sections according to BRD best practices.

  Returns {:ok, brd_content} or {:error, reason}
  """
  def enhance_parsed_text(parsed_text, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    model_spec = build_model_spec(provider)

    prompt = build_enhancement_prompt()

    messages = [
      %{role: "system", content: prompt},
      %{role: "user", content: parsed_text}
    ]

    # Pass artifact metadata to call_llm
    artifact_opts = [
      project_id: Keyword.get(opts, :project_id),
      type: "doc",
      category: Keyword.get(opts, :category, "Function Requirement Document"),
      title: Keyword.get(opts, :title, "Enhanced BRD")
    ]

    call_llm(model_spec, messages, artifact_opts)
  end

  @doc """
  Generates a comprehensive architectural plan using LLM based on project context.

  Takes the full project context including:
  - BRD content (business requirements)
  - Elicitation data (technical requirements and clarifications)
  - Tech stack configuration (selected technologies)

  Returns {:ok, plan_content} or {:error, reason}
  """
  def generate_architectural_plan(context, opts \\ []) do
    provider = Keyword.get(opts, :provider, :openai)
    model_spec = build_model_spec(provider)

    prompt = build_architectural_plan_prompt()

    messages = [
      %{role: "system", content: prompt},
      %{role: "user", content: context}
    ]

    Logger.info("Generating architectural plan with LLM provider: #{inspect(provider)}")

    # Pass artifact metadata to call_llm
    artifact_opts = [
      project_id: Keyword.get(opts, :project_id),
      type: "doc",
      category: Keyword.get(opts, :category, "Architectural Document"),
      title: Keyword.get(opts, :title, "Architectural Plan")
    ]

    # Use call_llm with higher max_tokens for architectural plans (12+ pages requires significant tokens)
    # We need to call ReqLLM directly here since call_llm uses max_tokens: 4000
    # For a 12+ page document, we need at least 16000 tokens (approximately 1000-1500 tokens per page)
    case ReqLLM.generate_text(model_spec, messages, temperature: 0.7, max_tokens: 16000) do
      {:ok, %ReqLLM.Response{message: message}} ->
        content = extract_text_from_message(message)
        Logger.info("Successfully generated architectural plan from LLM")

        # Store the ARCHITECTURAL DOCUMENT (LLM response) as an artifact
        # The BRD is input only - this artifact contains the generated architectural document
        store_artifact_if_requested(content, build_full_prompt_from_messages(messages), artifact_opts)

        {:ok, content}

      {:error, reason} ->
        Logger.error("LLM API error generating architectural plan: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Exception calling LLM for architectural plan: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp build_model_spec(:openai), do: "openai:gpt-4o-mini"
  defp build_model_spec(:anthropic), do: "anthropic:claude-3-5-sonnet-20241022"
  defp build_model_spec(:google), do: "google:gemini-1.5-pro"

  # If the provider is already a full model spec (contains :), return as-is
  defp build_model_spec(provider) when is_binary(provider) do
    if String.contains?(provider, ":") do
      provider
    else
      # Convert string provider to atom and use proper model spec
      # Handle known providers explicitly for safety
      provider_atom =
        case String.downcase(provider) do
          "openai" -> :openai
          "anthropic" -> :anthropic
          "google" -> :google
          _ ->
            # Try to convert to existing atom, fallback to openai
            try do
              String.to_existing_atom(provider)
            rescue
              ArgumentError ->
                Logger.warning("Unknown provider string '#{provider}', defaulting to openai")
                :openai
            end
        end

      build_model_spec(provider_atom)
    end
  end

  # Unknown provider atoms default to openai
  defp build_model_spec(provider) when is_atom(provider), do: "openai:gpt-4o-mini"

  defp call_llm(model_spec, messages, opts \\ []) do
    Logger.info("Calling LLM with model: #{inspect(model_spec)}")

    # Extract full prompt from messages for artifact storage
    full_prompt = build_full_prompt_from_messages(messages)

    case ReqLLM.generate_text(model_spec, messages, temperature: 0.7, max_tokens: 4000) do
      {:ok, %ReqLLM.Response{message: message}} ->
        content = extract_text_from_message(message)
        Logger.info("Successfully generated BRD from LLM")

        # Store artifact if project_id and metadata are provided
        store_artifact_if_requested(content, full_prompt, opts)

        {:ok, content}

      {:error, reason} ->
        Logger.error("LLM API error: #{inspect(reason)}")
        {:error, reason}

      unexpected ->
        Logger.error("Unexpected LLM response format: #{inspect(unexpected)}")
        {:error, :unexpected_response}
    end
  rescue
    error ->
      Logger.error("Exception calling LLM: #{inspect(error)}")
      {:error, {:exception, error}}
  end

  defp build_full_prompt_from_messages(messages) do
    messages
    |> Enum.map(fn
      %{role: role, content: content} ->
        "#{String.upcase(to_string(role))}:\n#{content}"
      _ ->
        ""
    end)
    |> Enum.filter(&(&1 != ""))
    |> Enum.join("\n\n---\n\n")
  end

  defp store_artifact_if_requested(content, full_prompt, opts) do
    project_id = Keyword.get(opts, :project_id)
    type = Keyword.get(opts, :type, "doc")
    category = Keyword.get(opts, :category, "Other")
    title = Keyword.get(opts, :title, "LLM Response")

    if project_id do
      case Artifacts.create_artifact(%{
             project_id: project_id,
             type: type,
             category: category,
             title: title,
             content: content,
             prompt: full_prompt
           }) do
        {:ok, artifact} ->
          Logger.info("Stored LLM artifact #{artifact.id} for project #{project_id}")

        {:error, changeset} ->
          Logger.warning(
            "Failed to store LLM artifact for project #{project_id}: #{inspect(changeset.errors)}"
          )
      end
    end
  end

  defp extract_text_from_message(%ReqLLM.Message{content: content}) when is_list(content) do
    content
    |> Enum.map(fn
      %{text: text} -> text
      %{"text" => text} -> text
      _ -> ""
    end)
    |> Enum.join("\n")
  end

  defp extract_text_from_message(%ReqLLM.Message{content: content}) when is_binary(content) do
    content
  end

  defp extract_text_from_message(_), do: ""

  defp build_conversion_prompt(filename) do
    """
    You are an expert business analyst specializing in creating comprehensive Business Requirements Documents (BRDs).

    The user has uploaded a file named "#{filename}" that contains project information, requirements, or notes.
    Your task is to convert this content into a professional, well-structured BRD following industry best practices.

    The BRD should include the following sections:

    1. **Executive Summary** - Brief overview of the project
    2. **Project Overview** - Detailed description of the project purpose and goals
    3. **Business Objectives** - Clear, measurable business objectives
    4. **Stakeholders** - Key stakeholders and their roles
    5. **Functional Requirements** - Detailed functional requirements organized by category
    6. **Non-Functional Requirements** - Performance, security, scalability, etc.
    7. **User Stories** (if applicable) - User-focused requirement descriptions
    8. **Acceptance Criteria** - Clear criteria for requirement validation
    9. **Assumptions and Constraints** - Known assumptions and limitations
    10. **Success Metrics** - How success will be measured

    Format the output in clean Markdown with proper headings, lists, and sections.
    Fill in any missing sections with reasonable assumptions based on the provided content.
    If information is incomplete, note it as "TBD - To Be Determined" rather than omitting the section.

    Be thorough, professional, and ensure the BRD is ready for stakeholder review.
    """
  end

  defp build_enhancement_prompt do
    """
    You are an expert business analyst specializing in creating comprehensive Business Requirements Documents (BRDs).

    The user has provided text content extracted from a document. Your task is to enhance and structure this content
    into a professional, well-structured BRD following industry best practices.

    The BRD should include the following sections:

    1. **Executive Summary** - Brief overview of the project
    2. **Project Overview** - Detailed description of the project purpose and goals
    3. **Business Objectives** - Clear, measurable business objectives
    4. **Stakeholders** - Key stakeholders and their roles
    5. **Functional Requirements** - Detailed functional requirements organized by category
    6. **Non-Functional Requirements** - Performance, security, scalability, etc.
    7. **User Stories** (if applicable) - User-focused requirement descriptions
    8. **Acceptance Criteria** - Clear criteria for requirement validation
    9. **Assumptions and Constraints** - Known assumptions and limitations
    10. **Success Metrics** - How success will be measured

    Analyze the provided text and:
    - Extract and organize all relevant information
    - Add proper structure and formatting (Markdown)
    - Fill in missing sections with reasonable inferences
    - Expand brief points into complete requirement statements
    - Add acceptance criteria for key requirements
    - Note any gaps as "TBD - To Be Determined"

    Produce a thorough, professional BRD ready for stakeholder review.
    """
  end

  defp build_architectural_plan_prompt do
    """
    You are a Senior Solutions Architect with expertise in cloud-native SaaS applications,
    enterprise software systems, and scalable distributed architectures. You are well-versed in
    the works of Martin Fowler, Boris Golden, Alex Xu, and enterprise architecture frameworks
    such as TOGAF.

    **CRITICAL REQUIREMENTS:**
    1. Generate a comprehensive ARCHITECTURAL DOCUMENT (NOT a BRD) that is AT LEAST 12 PAGES in length
    2. The Business Requirements Document (BRD) and project context provided below are INPUTS only
    3. Use the BRD to understand requirements, but focus entirely on technical architecture design
    4. Provide extremely detailed technical specifications, strategies, and implementation guidance
    5. Reference architectural patterns and best practices from industry experts
    6. Include specific technical recommendations with justifications

    # Phase 1: Requirements Analysis (Input Processing)

    **1. Extract and analyze requirements from the provided BRD and project context:**

    * **Functional Requirements:** List the core user interactions and system behaviors identified from the BRD.

    * **Non-Functional Requirements (NFRs):** Identify and quantify required:
      - **Performance:** Target latency, throughput, and response time requirements (e.g., API latency < 100ms, system must handle 10,000 concurrent users)
      - **Scalability:** Expected growth patterns, peak load requirements, and scaling targets
      - **Security:** Authentication, authorization, data protection, and compliance requirements
      - **Availability (SLA):** Uptime requirements, service level objectives (e.g., 99.9% availability)
      - **Disaster Recovery:** Recovery Time Objective (RTO) and Recovery Point Objective (RPO) requirements
      - **Maintainability:** Code quality standards, documentation requirements, and technical debt tolerance

    # Phase 2: Architectural Proposal

    **2. Propose the optimal high-level architecture:**

    * **Architectural Pattern:** Recommend the most suitable pattern (e.g., Microservices, Event-Driven, Monolith, Serverless, Hybrid) and **justify your choice** against the identified NFRs and functional requirements.

    * **Technology Stack (High-Level):** Propose primary technologies for:
      - **Compute:** Container orchestration (e.g., Kubernetes), serverless platforms, or application servers
      - **Data Stores:** Relational databases (e.g., PostgreSQL), NoSQL databases (e.g., MongoDB), caching layers (e.g., Redis), and search engines
      - **Messaging/Integration:** Message brokers (e.g., Kafka, RabbitMQ), API gateways, and service mesh technologies
      - **Infrastructure:** Deployment model (e.g., Hybrid, Multi-Region Active-Passive, Single-Region with DR), cloud provider considerations

    * **System Components:** Identify major components, their responsibilities, and data flow between them. Include a high-level architecture diagram description in text/ASCII format.

    # Phase 3: Detailed Best Practices Plan

    **3. Provide a detailed section on best practices implementation for the following four critical areas:**

    * **Data Strategy:**
      - Define the data flow architecture and data partitioning strategy
      - Specify backup/restore approach and data retention policies
      - Provide a high-level schema diagram or entity relationship overview for the most critical entities
      - Detail data consistency models (ACID vs. eventual consistency) and transaction handling
      - Address data migration and versioning strategies

    * **Scalability & Elasticity:**
      - Detail how the system will scale (horizontal vs. vertical scaling)
      - Specify auto-scaling groups, policies, and triggers
      - Define sharding/partitioning strategy for databases
      - Address peak load requirements from the NFRs with specific scaling targets
      - Include capacity planning and resource optimization recommendations

    * **Security:**
      - Outline a layered security model covering:
        - **Authentication/Authorization:** OAuth 2.0/OIDC implementation, role-based access control (RBAC), or attribute-based access control (ABAC)
        - **Data Encryption:** At rest (database encryption, file system encryption) and in transit (TLS/SSL)
        - **Network Security:** VPC design, network segmentation, Web Application Firewall (WAF), DDoS protection
        - **Vulnerability Management:** Security scanning, patch management, dependency management
      - Address compliance requirements (GDPR, HIPAA, SOC 2, etc.) if applicable
      - Include API security measures (rate limiting, input validation, API keys)

    * **Observability:**
      - Describe tools and strategy for:
        - **Monitoring (Metrics):** Key performance indicators (KPIs), business metrics, infrastructure metrics, and alerting thresholds
        - **Logging:** Centralized logging platform, log aggregation, retention policies, and log analysis
        - **Tracing:** Distributed tracing implementation, request correlation, and performance analysis
      - Define Service Level Indicators (SLIs) and Service Level Objectives (SLOs)
      - Include incident response and on-call procedures

    # Phase 4: Additional Considerations

    **4. Address the following additional architectural concerns:**

    * **Integration Architecture:**
      - Third-party service integration patterns (REST, GraphQL, gRPC, message queues)
      - API design approach (RESTful principles, versioning strategy)
      - Error handling, retry logic, circuit breakers, and fallback mechanisms
      - Rate limiting and throttling strategies

    * **Deployment Architecture:**
      - CI/CD pipeline design (build, test, deploy stages)
      - Environment strategy (dev, staging, production)
      - Infrastructure as Code (IaC) approach
      - Blue-green or canary deployment strategies

    * **Development Workflow:**
      - Recommended project structure and code organization
      - Testing strategy (unit, integration, end-to-end, performance testing)
      - Code quality standards and review process
      - Documentation requirements

    * **Risk Assessment & Mitigation:**
      - Identified technical risks and their impact
      - Mitigation strategies for each risk
      - Contingency plans and rollback procedures

    * **Implementation Phases:**
      - Phase 1: MVP/Core features with timeline and dependencies
      - Phase 2: Enhanced features with timeline
      - Phase 3: Optimization and scaling with timeline

    * **Success Metrics:**
      - KPIs to measure system success
      - Performance benchmarks and targets
      - User experience metrics

    # Deliverable Format

    **5. Present the final ARCHITECTURAL DOCUMENT in a structured, professional format:**

    **CRITICAL: This must be an ARCHITECTURAL DOCUMENT, not a requirements document.**
    Focus on technical design, system architecture, technology choices, and implementation strategies.
    Do NOT regenerate or rewrite the BRD - use it only as input to inform your architectural decisions.

    - Use clear Markdown formatting with proper headings (H1, H2, H3)
    - Include tables for comparing technology options or architectural patterns
    - Use bullet points and numbered lists for clarity
    - Include code blocks or architecture diagrams (in text/ASCII format) where appropriate
    - Ensure the document is comprehensive, actionable, and ready for development teams
    - The architectural document should be detailed enough for a development team to begin implementation with clear guidance on architectural decisions, technology choices, and design patterns

    # Phase 5: Advanced Technical Strategies and Best Practices

    **5. Provide comprehensive coverage of the following critical technical areas:**

    * **Caching Strategies:**
      - Multi-layer caching architecture (CDN, application-level, database query caching)
      - Cache invalidation strategies and patterns (write-through, write-behind, cache-aside)
      - Distributed caching solutions (Redis, Memcached) with replication and failover strategies
      - Cache warming strategies for critical data paths
      - Cache coherency and consistency models
      - Performance optimization through intelligent cache placement
      - Reference Martin Fowler's patterns on caching strategies

    * **Data Cataloging and Metadata Management:**
      - Comprehensive data cataloging strategy for digital assets
      - Metadata schema design and extensibility
      - Tagging and classification systems
      - Search indexing strategies (full-text search, faceted search, semantic search)
      - Data lineage and provenance tracking
      - Catalog API design for metadata operations
      - Integration with AI/ML for automated tagging and classification

    * **UUID Usage and Optimizations:**
      - UUID strategy selection (UUIDv4 vs UUIDv7 vs ULID) with performance implications
      - Database indexing strategies for UUIDs (B-tree vs hash indexes)
      - UUID storage optimization (binary vs string representation)
      - Distributed ID generation strategies to avoid collisions
      - Performance impact analysis and mitigation techniques
      - Reference Alex Xu's "System Design Interview" insights on ID generation

    * **Containerization Strategy:**
      - Container orchestration platform selection and justification (Kubernetes, Docker Swarm, etc.)
      - Container image optimization strategies (multi-stage builds, minimal base images)
      - Container security best practices (image scanning, runtime security)
      - Resource allocation and limits (CPU, memory, storage)
      - Container networking architecture (service mesh, ingress/egress)
      - Stateful vs stateless container design patterns
      - Container lifecycle management and auto-scaling

    * **12-Factor App Principles:**
      - Detailed implementation of each of the 12 factors:
        1. Codebase: One codebase tracked in revision control, many deploys
        2. Dependencies: Explicitly declare and isolate dependencies
        3. Config: Store config in the environment
        4. Backing services: Treat backing services as attached resources
        5. Build, release, run: Strictly separate build and run stages
        6. Processes: Execute the app as one or more stateless processes
        7. Port binding: Export services via port binding
        8. Concurrency: Scale out via the process model
        9. Disposability: Maximize robustness with fast startup and graceful shutdown
        10. Dev/prod parity: Keep development, staging, and production as similar as possible
        11. Logs: Treat logs as event streams
        12. Admin processes: Run admin/management tasks as one-off processes
      - Practical implementation guidance for each factor
      - Reference Martin Fowler's work on 12-factor applications

    * **Secret Management:**
      - Secret management architecture (HashiCorp Vault, AWS Secrets Manager, Azure Key Vault)
      - Secret rotation strategies and automation
      - Secret injection patterns (environment variables, mounted volumes, API calls)
      - Secret encryption at rest and in transit
      - Access control and audit logging for secrets
      - Integration with CI/CD pipelines for secret management
      - Compliance considerations for secret handling

    * **Scalability Deep Dive:**
      - Horizontal vs vertical scaling strategies with cost-benefit analysis
      - Database scaling patterns (read replicas, sharding, partitioning)
      - Application scaling patterns (stateless design, session management)
      - Auto-scaling policies and triggers (CPU, memory, custom metrics)
      - Load balancing strategies (round-robin, least connections, geographic)
      - Caching as a scaling mechanism
      - Reference Alex Xu's scalability patterns and Boris Golden's distributed systems insights

    * **AI/ML Integration Opportunities:**
      - Identify specific use cases where AI/ML can enhance the system:
        - Automated content tagging and classification
        - Intelligent search and recommendation systems
        - Anomaly detection for security and operations
        - Predictive analytics for capacity planning
        - Natural language processing for content analysis
        - Computer vision for image/video asset processing
      - AI/ML architecture patterns (model serving, feature stores, MLOps)
      - Integration points with existing system architecture
      - Cost-benefit analysis of AI/ML features

    * **TOGAF Enterprise Architecture Alignment:**
      - Business Architecture: How the technical architecture supports business objectives
      - Application Architecture: Application portfolio and integration patterns
      - Data Architecture: Data models, data governance, and data flow
      - Technology Architecture: Technology stack, infrastructure, and platform decisions
      - Architecture principles and governance model
      - Reference TOGAF ADM (Architecture Development Method) phases

    * **Reference Industry Experts:**
      - **Martin Fowler:** Apply patterns from "Patterns of Enterprise Application Architecture"
        - Domain-Driven Design (DDD) patterns
        - Microservices patterns and anti-patterns
        - Event-driven architecture patterns
        - Refactoring strategies
      - **Boris Golden:** Distributed systems patterns
        - Consistency models (strong, eventual, causal)
        - Distributed transaction patterns
        - Consensus algorithms where applicable
      - **Alex Xu:** System design patterns from "System Design Interview"
        - Scalability patterns
        - Database design patterns
        - Caching strategies
        - Load balancing approaches

    # Phase 6: Comprehensive Document Structure

    **6. Structure your ARCHITECTURAL DOCUMENT with the following comprehensive sections:**

    **CRITICAL: This must be an ARCHITECTURAL DOCUMENT, not a requirements document.**
    The document must be AT LEAST 12 PAGES of detailed technical content.

    1. **Executive Summary** (1-2 pages)
       - High-level architectural approach and key decisions
       - Technology stack overview
       - Critical architectural patterns selected
       - Expected outcomes and benefits

    2. **Architecture Overview** (2-3 pages)
       - System architecture diagram (detailed text/ASCII description)
       - Component architecture and interactions
       - Data flow architecture
       - Deployment architecture
       - Reference architecture patterns (TOGAF alignment)

    3. **Technology Stack Deep Dive** (2-3 pages)
       - Detailed technology selection with justifications
       - Technology comparison tables
       - Integration patterns between technologies
       - Version and compatibility considerations

    4. **Data Architecture** (1-2 pages)
       - Database schema design (detailed entity relationships)
       - Data cataloging and metadata strategy
       - UUID strategy and optimization
       - Data partitioning and sharding strategies
       - Data consistency models
       - Backup and disaster recovery architecture

    5. **Caching Architecture** (1-2 pages)
       - Multi-layer caching strategy
       - Cache placement and topology
       - Cache invalidation patterns
       - Performance optimization through caching
       - Cache monitoring and metrics

    6. **Scalability Architecture** (1-2 pages)
       - Horizontal and vertical scaling strategies
       - Auto-scaling policies and implementation
       - Database scaling patterns
       - Load balancing architecture
       - Capacity planning and resource optimization

    7. **Security Architecture** (1-2 pages)
       - Authentication and authorization architecture
       - Secret management implementation
       - Data encryption strategy
       - Network security design
       - Compliance and audit architecture

    8. **Containerization and Deployment** (1-2 pages)
       - Container orchestration architecture
       - 12-Factor App implementation details
       - CI/CD pipeline architecture
       - Deployment strategies (blue-green, canary, rolling)
       - Infrastructure as Code (IaC) approach

    9. **Integration Architecture** (1 page)
       - API design and versioning
       - Service integration patterns
       - Event-driven architecture
       - Error handling and resilience patterns

    10. **AI/ML Integration** (1 page)
        - AI/ML use cases and architecture
        - Model serving infrastructure
        - Integration patterns with core system

    11. **Observability and Operations** (1 page)
        - Monitoring architecture
        - Logging strategy
        - Distributed tracing
        - Alerting and incident response

    12. **Implementation Roadmap** (1 page)
        - Phased implementation plan
        - Dependencies and milestones
        - Risk mitigation strategies

    **Document Formatting Requirements:**
    - Use clear Markdown formatting with proper headings (H1, H2, H3, H4)
    - Include detailed tables for comparisons and specifications
    - Use bullet points and numbered lists extensively
    - Include code blocks, configuration examples, and architecture diagrams (text/ASCII)
    - Provide specific implementation guidance and examples
    - Include references to industry experts and frameworks where applicable
    - Ensure each section is comprehensive and detailed (aim for 1-2 pages per major section)

    **Quality Standards:**
    - Be extremely detailed and specific in all technical recommendations
    - Justify every architectural decision with clear reasoning
    - Reference industry best practices and expert insights
    - Provide actionable implementation guidance
    - Include performance considerations and optimization strategies
    - Address operational concerns and maintainability
    - Ensure the document is production-ready for development teams

    Remember: You are creating a comprehensive ARCHITECTURAL DOCUMENT that serves as a complete
    technical blueprint for implementation. The document must be detailed enough that a development
    team can begin implementation immediately with clear guidance on all architectural decisions.
    """
  end
end
