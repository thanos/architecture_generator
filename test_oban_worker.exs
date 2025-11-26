alias ArchitectureGenerator.{Repo, Projects.Project, Workers.PlanGenerationWorker}

# Update project to Queued status with test data
project =
  Repo.get!(Project, 2)
  |> Ecto.Changes
