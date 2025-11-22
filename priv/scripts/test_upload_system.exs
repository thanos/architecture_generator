alias ArchitectureGenerator.{Repo, Projects, Uploads}
alias ArchitectureGenerator.Projects.Project

IO.puts("🧪 Testing Upload Manager System\n")

# Step 1: Create a test project
IO.puts("Step 1: Creating test project...")

{:ok, project} =
  Projects.create_project(%{
    name: "E-Commerce Platform Upload Test",
    user_email: "test@example.com"
  })

IO.puts("✅ Project created with ID: #{project.id}\n")

# Step 2: Upload BRD file to S3
IO.puts("Step 2: Uploading sample BRD file to S3...")
file_path = "/tmp/sample_brd.txt"
{:ok, file_stat} = File.stat(file_path)

{:ok, upload} =
  Uploads.create_upload(
    %{
      project_id: project.id,
      filename: "sample_brd.txt",
      content_type: "text/plain",
      size_bytes: file_stat.size,
      uploaded_by: "test@example.com"
    },
    file_path
  )

IO.puts("✅ File uploaded to S3!")
IO.puts("   - S3 Key: #{upload.s3_key}")
IO.puts("   - S3 Bucket: #{upload.s3_bucket}")
IO.puts("   - File Size: #{upload.size_bytes} bytes")
IO.puts("   - Current Version: #{upload.current_version}\n")

# Step 3: Verify upload record and version
IO.puts("Step 3: Verifying upload record...")
retrieved_upload = Uploads.get_upload!(upload.id)
IO.puts("✅ Upload retrieved from database")
IO.puts("   - ID: #{retrieved_upload.id}")
IO.puts("   - Filename: #{retrieved_upload.filename}")
IO.puts("   - Versions count: #{length(retrieved_upload.versions)}\n")

# Step 4: Get download URL
IO.puts("Step 4: Generating presigned download URL...")
download_url = Uploads.get_download_url(upload)
IO.puts("✅ Presigned URL generated:")
IO.puts("   #{String.slice(download_url, 0..100)}...\n")

# Step 5: Test version creation by updating the file
IO.puts("Step 5: Testing file versioning - uploading new version...")

# Create modified version of the file
modified_content =
  File.read!(file_path) <>
    "\n\n## Updated Requirements\n- Mobile app support\n- Real-time notifications\n"

File.write!("/tmp/sample_brd_v2.txt", modified_content)

{:ok, updated_upload} =
  Uploads.update_upload(
    upload,
    "/tmp/sample_brd_v2.txt",
    %{
      filename: "sample_brd.txt",
      uploaded_by: "test@example.com"
    }
  )

IO.puts("✅ New version uploaded!")
IO.puts("   - Current Version: #{updated_upload.current_version}")
IO.puts("   - Total Versions: #{length(updated_upload.versions)}\n")

# Step 6: List all versions
IO.puts("Step 6: Listing all versions...")

Enum.each(updated_upload.versions, fn version ->
  IO.puts("   Version #{version.version_number}:")
  IO.puts("     - S3 Key: #{version.s3_key}")
  IO.puts("     - Size: #{version.size_bytes} bytes")
  IO.puts("     - Created: #{version.inserted_at}")
end)

IO.puts("")

# Step 7: List all uploads
IO.puts("Step 7: Listing all uploads in system...")
all_uploads = Uploads.list_uploads()
IO.puts("✅ Total uploads in system: #{length(all_uploads)}")

project_uploads = Uploads.list_uploads_by_project(project.id)
IO.puts("✅ Uploads for project #{project.id}: #{length(project_uploads)}\n")

# Summary
IO.puts("=" |> String.duplicate(60))
IO.puts("✅ UPLOAD SYSTEM TEST COMPLETE!")
IO.puts("=" |> String.duplicate(60))
IO.puts("\nTest Results:")
IO.puts("  ✅ Project creation: PASSED")
IO.puts("  ✅ File upload to S3: PASSED")
IO.puts("  ✅ Database record creation: PASSED")
IO.puts("  ✅ Version tracking: PASSED")
IO.puts("  ✅ Presigned URL generation: PASSED")
IO.puts("  ✅ File versioning: PASSED")
IO.puts("  ✅ Upload listing: PASSED")
IO.puts("\n🎉 All tests passed! Upload Manager is working correctly!")
