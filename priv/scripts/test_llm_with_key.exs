# This test allows you to paste your API key when prompted
IO.puts("🧪 LLM Integration Test")
IO.puts("=" |> String.duplicate(60))
IO.puts("\nThis test will verify the LLM integration works correctly.")
IO.puts("You'll need an OpenAI API key to proceed.\n")

IO.puts("Enter your OpenAI API key (or 'skip' to skip LLM tests):")
api_key = IO.gets("API Key: ") |> String.trim()

if api_key == "skip" or api_key == "" do
  IO.puts("\n⚠️  Skipping LLM tests")
  IO.puts("The system is ready - just set OPENAI_API_KEY when you want to use LLM features")
  System.halt(0)
end

# Set the API key for this session
System.put_env("OPENAI_API_KEY", api_key)

IO.puts("\n✅ API key set for this test session")
IO.puts("Starting LLM integration test...\n")

# Now run the actual test
Code.require_file("test_llm_end_to_end.exs", __DIR__)
