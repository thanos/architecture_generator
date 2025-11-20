defmodule ArchitectureGenerator.Repo do
  use Ecto.Repo,
    otp_app: :architecture_generator,
    adapter: Ecto.Adapters.Postgres
end
