# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :architecture_generator,
  ecto_repos: [ArchitectureGenerator.Repo],
  generators: [timestamp_type: :utc_datetime]

# Configures Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Configures Oban for background jobs
config :architecture_generator, Oban,
  repo: ArchitectureGenerator.Repo,
  notifier: Oban.Notifiers.Postgres,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

# Configures the endpoint
import_config "#{config_env()}.exs"
