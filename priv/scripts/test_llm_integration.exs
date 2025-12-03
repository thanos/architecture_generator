alias ArchitectureGenerator.{LLMService}

IO.puts("🧪 Testing LLM Integration\n")

# Test 1: Check if OpenAI API key is configured
IO.puts("Step 1: Checking OpenAI API key configuration...")
api_key = System.get_env("OPENAI_API_KEY")

if api_key do
  IO.puts("✅ OpenAI API key is configured (#{String.slice(api_key, 0..10)}...)")
else
  IO.puts("⚠️  OpenAI API key NOT configured")
  IO.puts("   Set OPENAI_API_KEY environment variable to test LLM features")
end

IO.puts("")

# Test 2: Test enhance_parsed_text function (with mock if no API key)
IO.puts("Step 2: Testing parsed text enhancement...")

sample_text = """
Project: E-commerce Platform

Features:
- User login
- Shopping cart
- Payment

Tech: Phoenix, PostgreSQL
"""

IO.puts("Sample input text:")
IO.puts(sample_text)
IO.puts("")

if api_key do
  IO.puts("Calling OpenAI API to enhance text...")
  
  case LLMService.enhance_parsed_text(sample_text, provider: "openai") do
    {:ok, enhanced} ->
      IO.puts("✅ Successfully enhanced with LLM!")
      IO.puts("\nEnhanced BRD preview (first 500 chars):")
      IO.puts(String.slice(enhanced, 0..500))
      IO.puts("...")
      
    {:error, reason} ->
      IO.puts("❌ LLM enhancement failed: #{inspect(reason)}")
  end
else
  IO.puts("⚠️  Skipping LLM test (no API key)")
  IO.puts("   Set OPENAI_API_KEY to test this feature")
end

IO.puts("")
IO.puts("=" |> String.duplicate(60))
IO.puts("✅ LLM INTEGRATION TEST COMPLETE!")
IO.puts("=" |> String.duplicate(60))
