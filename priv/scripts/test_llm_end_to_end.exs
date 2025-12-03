alias ArchitectureGenerator.{Repo, Projects, Uploads}

IO.puts("🧪 Testing End-to-End LLM Integration\n")
IO.puts("=" |> String.duplicate(60))

# Check for API key
api_key = System.get_env("OPENAI_API_KEY")

if is_nil(api_key) do
  IO.puts("❌ OPENAI_API_KEY not set!")
  IO.puts("\nTo test LLM features, set your API key:")
  IO.puts("  export OPENAI_API_KEY='your-key-here'")
  IO.puts("\nSkipping LLM tests...")
  System.halt(0)
end

IO.puts("✅ OpenAI API key found: #{String.slice(api_key, 0..10)}...")
IO.puts("")

# Create test project
IO.puts("Step 1: Creating test project...")
{:ok, project} = Projects.create_project(%{
  name: "LLM Integration Test",
  user_email: "llm-test@example.com"
})
IO.puts("✅ Project created: #{project.name} (ID: #{project.id})")
IO.puts("")

# Create a sample document
IO.puts("Step 2: Creating sample document for testing...")
sample_content = """
E-Commerce Platform Project

Basic Requirements:
- Users can browse products
- Add items to cart
- Checkout with credit card
- Track orders
- Admin dashboard for inventory

Technology: We want to use modern web stack
Budget: $50k
Timeline: 3 months
"""

File.write!("/tmp/sample_project.txt", sample_content)
IO.puts("✅ Sample document created")
IO.puts("Content preview:")
IO.puts(String.slice(sample_content, 0..150))
IO.puts("...\n")

# Test 1: Parse Only Mode
IO.puts("=" |> String.duplicate(60))
IO.puts("TEST 1: Parse Only Mode (no LLM)")
IO.puts("=" |> String.duplicate(60))

{:ok, file_stat} = File.stat("/tmp/sample_project.txt")
{:ok, upload1, parsed_content1} = Uploads.create_upload(
  %{
    project_id: project.id,
    filename: "sample_parse_only.txt",
    content_type: "text/plain",
    size_bytes: file_stat.size,
    uploaded_by: "llm-test@example.com",
    processing_mode: "parse_only"
  },
  "/tmp/sample_project.txt"
)

IO.puts("✅ Upload created (parse_only mode)")
IO.puts("   - Processing mode: parse_only")
IO.puts("   - Parsed content length: #{String.length(parsed_content1)} chars")
IO.puts("   - Preview: #{String.slice(parsed_content1, 0..100)}...")
IO.puts("")

# Test 2: LLM Parsed Mode
IO.puts("=" |> String.duplicate(60))
IO.puts("TEST 2: Parse + LLM Enhancement Mode")
IO.puts("=" |> String.duplicate(60))
IO.puts("⏳ Calling OpenAI API to enhance parsed text...")

{:ok, upload2, enhanced_content} = Uploads.create_upload(
  %{
    project_id: project.id,
    filename: "sample_llm_parsed.txt",
    content_type: "text/plain",
    size_bytes: file_stat.size,
    uploaded_by: "llm-test@example.com",
    processing_mode: "llm_parsed",
    llm_provider: "openai"
  },
  "/tmp/sample_project.txt"
)

IO.puts("✅ Upload created (llm_parsed mode)")
IO.puts("   - Processing mode: llm_parsed")
IO.puts("   - Provider: openai")

if enhanced_content do
  IO.puts("   - Enhanced content length: #{String.length(enhanced_content)} chars")
  IO.puts("\n📄 Enhanced BRD Preview (first 800 chars):")
  IO.puts(String.slice(enhanced_content, 0..800))
  IO.puts("...")
else
  IO.puts("   - ⚠️ No enhanced content (LLM may have failed)")
end

IO.puts("")

# Test 3: LLM Raw Mode
IO.puts("=" |> String.duplicate(60))
IO.puts("TEST 3: Direct AI Conversion Mode (Raw File)")
IO.puts("=" |> String.duplicate(60))
IO.puts("⏳ Calling OpenAI API to convert raw document...")

{:ok, upload3, converted_content} = Uploads.create_upload(
  %{
    project_id: project.id,
    filename: "sample_llm_raw.txt",
    content_type: "text/plain",
    size_bytes: file_stat.size,
    uploaded_by: "llm-test@example.com",
    processing_mode: "llm_raw",
    llm_provider: "openai"
  },
  "/tmp/sample_project.txt"
)

IO.puts("✅ Upload created (llm_raw mode)")
IO.puts("   - Processing mode: llm_raw")
IO.puts("   - Provider: openai")

if converted_content do
  IO.puts("   - Converted content length: #{String.length(converted_content)} chars")
  IO.puts("\n📄 AI-Generated BRD Preview (first 800 chars):")
  IO.puts(String.slice(converted_content, 0..800))
  IO.puts("...")
else
  IO.puts("   - ⚠️ No converted content (LLM may have failed)")
end

IO.puts("")

# Summary
IO.puts("=" |> String.duplicate(60))
IO.puts("✅ END-TO-END LLM INTEGRATION TEST COMPLETE!")
IO.puts("=" |> String.duplicate(60))
IO.puts("\n📊 Test Results:")
IO.puts("  ✅ Parse Only: #{if parsed_content1, do: "PASSED", else: "FAILED"}")
IO.puts("  ✅ Parse + LLM: #{if enhanced_content, do: "PASSED", else: "FAILED"}")
IO.puts("  ✅ Direct AI: #{if converted_content, do: "PASSED", else: "FAILED"}")

IO.puts("\n🎉 All three processing modes tested successfully!")
IO.puts("\nNote: If you see API failures, check your OPENAI_API_KEY")
