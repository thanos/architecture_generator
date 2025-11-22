alias ArchitectureGenerator.LLMService

IO.puts("🧪 Testing ReqLLM Integration\n")

sample_text = """
Project: E-Commerce Platform
We need a modern online store for selling products.
Users should be able to browse products, add to cart, and checkout.
Expected users: 10,000 daily
Must support credit card payments
"""

IO.puts("Testing Parse + LLM Enhancement mode...")
case LLMService.enhance_parsed_text(sample_text, provider: "openai") do
  {:ok, enhanced_brd} ->
    IO.puts("✅ SUCCESS!")
    IO.puts("\nGenerated BRD (first 500 chars):")
    IO.puts(String.slice(enhanced_brd, 0..500))
    
  {:error, reason} ->
    IO.puts("❌ FAILED: #{inspect(reason)}")
end
