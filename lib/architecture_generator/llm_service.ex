defmodule ArchitectureGenerator.LLMService do
  @moduledoc """
  Service for interacting with LLM providers (OpenAI) to generate and enhance BRDs.
  """

  require Logger

  @doc """
  Converts a raw document to a canonical best-practice BRD using an LLM.

  Takes the raw file content (binary) and sends it to the LLM with instructions
  to convert it into a well-structured Business Requirements Document.

  Returns {:ok, brd_content} or {:error, reason}
  """
  def convert_document_to_brd(file_content, filename, opts \\ []) do
    provider = Keyword.get(opts, :provider, "openai")

    case provider do
      "openai" -> convert_with_openai(file_content, filename)
      _ -> {:error, :unsupported_provider}
    end
  end

  @doc """
  Enhances already-parsed text content with LLM to create a canonical BRD.

  Takes parsed text and sends it to the LLM with instructions to enhance,
  structure, and fill in missing sections according to BRD best practices.

  Returns {:ok, brd_content} or {:error, reason}
  """
  def enhance_parsed_text(parsed_text, opts \\ []) do
    provider = Keyword.get(opts, :provider, "openai")

    case provider do
      "openai" -> enhance_with_openai(parsed_text)
      _ -> {:error, :unsupported_provider}
    end
  end

  # Private OpenAI integration functions

  defp convert_with_openai(file_content, filename) do
    api_key = get_openai_api_key()

    if is_nil(api_key) do
      Logger.error("OpenAI API key not configured")
      {:error, :missing_api_key}
    else
      prompt = build_conversion_prompt(filename)

      # For binary content, we'll convert to text representation
      # In a real implementation, you might want to use GPT-4 Vision for images/PDFs
      text_content =
        if is_binary(file_content), do: inspect(file_content, limit: 5000), else: file_content

      call_openai(api_key, prompt, text_content)
    end
  end

  defp enhance_with_openai(parsed_text) do
    api_key = get_openai_api_key()

    if is_nil(api_key) do
      Logger.error("OpenAI API key not configured")
      {:error, :missing_api_key}
    else
      prompt = build_enhancement_prompt()
      call_openai(api_key, prompt, parsed_text)
    end
  end

  defp call_openai(api_key, system_prompt, user_content) do
    Logger.info("Calling OpenAI API to generate BRD")

    request_body = %{
      model: "gpt-4o-mini",
      messages: [
        %{role: "system", content: system_prompt},
        %{role: "user", content: user_content}
      ],
      temperature: 0.7,
      max_tokens: 4000
    }

    case OpenAI.chat_completion(
           model: request_body.model,
           messages: request_body.messages,
           temperature: request_body.temperature,
           max_tokens: request_body.max_tokens,
           api_key: api_key
         ) do
      {:ok, %{choices: [%{"message" => %{"content" => content}} | _]}} ->
        Logger.info("Successfully generated BRD from OpenAI")
        {:ok, content}

      {:ok, response} ->
        Logger.error("Unexpected OpenAI response format: #{inspect(response)}")
        {:error, :unexpected_response}

      {:error, reason} ->
        Logger.error("OpenAI API error: #{inspect(reason)}")
        {:error, reason}
    end
  rescue
    error ->
      Logger.error("Exception calling OpenAI: #{inspect(error)}")
      {:error, {:exception, error}}
  end

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

  defp get_openai_api_key do
    System.get_env("OPENAI_API_KEY") ||
      Application.get_env(:architecture_generator, :openai_api_key)
  end
end
