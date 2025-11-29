defmodule ArchitectureGenerator.LLMService do
  @moduledoc """
  Service for interacting with LLM providers using ReqLLM to generate and enhance BRDs.
  """

  require Logger

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

    call_llm(model_spec, messages)
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

    call_llm(model_spec, messages)
  end

  defp build_model_spec(:openai), do: "openai:gpt-4o-mini"
  defp build_model_spec(:anthropic), do: "anthropic:claude-3-5-sonnet-20241022"
  defp build_model_spec(:google), do: "google:gemini-1.5-pro"

  # If the provider is already a full model spec (contains :), return as-is
  defp build_model_spec(provider) when is_binary(provider) do
    if String.contains?(provider, ":") do
      provider
    else
      # Fallback: assume it's a provider name and use a generic model
      "#{provider}:default"
    end
  end

  # Unknown provider atoms default to openai
  defp build_model_spec(provider) when is_atom(provider), do: "openai:gpt-4o-mini"

  defp call_llm(model_spec, messages) do
    Logger.info("Calling LLM with model: #{inspect(model_spec)}")

    case ReqLLM.generate_text(model_spec, messages, temperature: 0.7, max_tokens: 4000) do
      {:ok, %ReqLLM.Response{message: message}} ->
        content = extract_text_from_message(message)
        Logger.info("Successfully generated BRD from LLM")
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
end
