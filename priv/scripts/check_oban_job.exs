alias ArchitectureGenerator.Repo
import Ecto.Query

job = from(j in Oban.Job, order_by: [desc: j.id], limit: 1) |> Repo.one()

if job do
  IO.puts("Job ID: #{job.id}")
  IO.puts("State: #{job.state}")
  IO.puts("Worker: #{job.worker}")
  IO.puts("Attempt: #{job.attempt}/#{job.max_attempts}")
  
  if job.errors != [] do
    IO.puts("\nErrors:")
    IO.inspect(job.errors, pretty: true, limit: :infinity)
  else
    IO.puts("\nNo errors recorded")
  end
  
  if job.state == "completed" do
    IO.puts("\n✅ Job completed successfully!")
  end
else
  IO.puts("No jobs found")
end
