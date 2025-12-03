alias ArchitectureGenerator.{Repo, Projects.Project, Workers.PlanGenerationWorker}
import Ecto.Query

IO.puts("🔍 Testing Plan Generation Worker\n")

project = Repo.get!(Project, 2)

IO.puts("📋 Project Status:")
IO.puts("  ID: #{project.id}")
IO.puts("  Name: #{project.name}")
IO.puts("  Status: #{project.status}")

IO.puts(
  "  BRD Length: #{if project.brd_content, do: String.length(project.brd_content), else: 0} chars"
)

IO.puts("  Has Elicitation Data: #{inspect(map_size(project.elicitation_data || %{}))}")
IO.puts("  Has Tech Stack: #{inspect(map_size(project.tech_stack_config || %{}))}")

IO.puts("\n🚀 Enqueuing Oban job...")

job =
  %{project_id: project.id}
  |> PlanGenerationWorker.new()
  |> Oban.insert!()

IO.puts("✅ Job enqueued with ID: #{job.id}")
IO.puts("⏳ Waiting for job to process...")
:timer.sleep(5000)

job_status = Repo.get(Oban.Job, job.id)
IO.puts("\n📊 Job Status: #{job_status.state}")

if job_status.errors != [] do
  IO.puts("❌ Errors: #{inspect(job_status.errors, pretty: true)}")
end

updated_project = Repo.get!(Project, 2) |> Repo.preload(:architectural_plan)
IO.puts("\n📦 Project Status After: #{updated_project.status}")

if updated_project.architectural_plan do
  IO.puts("✅ Plan Created!")
  IO.puts("   Preview: #{String.slice(updated_project.architectural_plan.content, 0..200)}...")
else
  IO.puts("❌ No plan created")
end
