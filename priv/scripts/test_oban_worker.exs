alias ArchitectureGenerator.{Repo, Projects.Project, Workers.PlanGenerationWorker}

project = Repo.get!(Project, 2)

IO.puts("Enqueueing plan generation for project #{project.id}...")

case %{project_id: project.id}
     |> PlanGenerationWorker.new()
     |> Oban.insert() do
  {:ok, job} ->
    IO.puts("Job enqueued successfully: #{inspect(job.id)}")
    IO.puts("Waiting for job to complete...")
    Process.sleep(5000)

    updated_project = Repo.get!(Project, project.id)
    IO.puts("Project status: #{updated_project.status}")

    if updated_project.architectural_plan_id do
      IO.puts("Architectural plan created with ID: #{updated_project.architectural_plan_id}")
    else
      IO.puts("No architectural plan created yet")
    end

  {:error, changeset} ->
    IO.puts("Failed to enqueue job:")
    IO.inspect(changeset.errors, label: "Changeset errors")
end
