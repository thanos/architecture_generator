alias ArchitectureGenerator.DocumentParser

IO.puts("🧪 Testing Word Document Parsing\n")

# Test with the uploaded DOCX file
docx_path = "priv/static/uploads/projects/8/1763835593_PMO-Template_Business_Requirements_Document_v1_1.docx"

if File.exists?(docx_path) do
  IO.puts("📘 Testing DOCX file: PMO-Template_Business_Requirements_Document_v1_1.docx")
  
  case DocumentParser.parse_file(docx_path) do
    {:ok, content} ->
      IO.puts("✅ DOCX file parsed successfully!")
      IO.puts("   - Content length: #{String.length(content)} characters")
      IO.puts("\n📄 First 1000 characters of parsed content:")
      IO.puts("=" |> String.duplicate(60))
      IO.puts(String.slice(content, 0..999))
      IO.puts("=" |> String.duplicate(60))
      
      # Check if we got meaningful content
      if String.length(content) > 100 do
        IO.puts("\n✅ WORD PARSER TEST: PASSED")
        IO.puts("   Successfully extracted #{String.length(content)} characters from Word document")
      else
        IO.puts("\n⚠️ WARNING: Content seems too short")
      end
      
    {:error, reason} ->
      IO.puts("❌ DOCX parsing failed: #{inspect(reason)}")
  end
else
  IO.puts("❌ DOCX file not found at: #{docx_path}")
  IO.puts("\nLet me check what files are available:")
  
  case File.ls("priv/static/uploads/projects") do
    {:ok, dirs} ->
      IO.puts("\nAvailable project directories:")
      Enum.each(dirs, fn dir ->
        path = "priv/static/uploads/projects/#{dir}"
        {:ok, files} = File.ls(path)
        IO.puts("  #{dir}/")
        Enum.each(files, fn file ->
          IO.puts("    - #{file}")
        end)
      end)
    {:error, _} ->
      IO.puts("No uploads directory found")
  end
end
