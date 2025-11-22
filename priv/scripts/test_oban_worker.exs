alias ArchitectureGenerator.{Repo, Projects.Project, Workers.PlanGenerationWorker}

# Update project to Queued status with test data
project =
  Repo.get!(Project, 2)
  |> Ecto.Changeset.change(%{
    status: "Queued",
    elicitation_data: %{
      "expected_users" => "100,000 concurrent users, 1M daily active users",
      "performance_requirements" => "Page load under 2 seconds, Search results under 500ms",
      "security_compliance" => "PCI-DSS",
      "integration_requirements" => "Stripe, PayPal, FedEx, Analytics",
      "data_volume" => "10M+ products, 500K daily transactions",
      "availability_requirements" => "99.9%"
    },
    tech_stack_config: %{
      "primary_language" => "Elixir",
      "web_framework" => "Phoenix LiveView",
      "database_system" => "PostgreSQL",
      "deployment_env" => "Fly.io"
    }
  })
  |> Repo.update!()

IO.puts("✅ Project updated to Queued status")

# Manually enqueue the Oban job
job =
  %{project_id: project.id}
  |> PlanGenerationWorker.new()
  |> Oban.insert!()

IO.puts("✅ Oban job inserted with ID: #{job.id}")
IO.puts("Waiting 3 seconds for job to process...")
:timer.sleep(3000)

# Check if job was processed
updated_project = Repo.get!(Project, 2) |> Repo.preload(:architectural_plan)
IO.puts("\nProject status: #{updated_project.status}")

if updated_project.architectural_plan do
  IO.puts("✅ Architectural plan created!")
  IO.puts("\nPlan preview:")
  IO.puts(String.slice(updated_project.architectural_plan.content, 0..300))
  IO.puts("...")
else
  IO.puts("❌ No architectural plan yet - job may still be processing")
end
