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

# Configures the endpoint
config :architecture_generator, ArchitectureGeneratorWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: ArchitectureGeneratorWeb.ErrorHTML, json: ArchitectureGeneratorWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: ArchitectureGenerator.PubSub,
  live_view: [signing_salt: "Vf9LrTsk"]

# Configures the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :architecture_generator, ArchitectureGenerator.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.25.4",
  architecture_generator: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.1.7",
  architecture_generator: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures Swoosh API Client
config :swoosh, :api_client, Swoosh.ApiClient.Finch

# Configures Oban for background jobs

# File storage configuration (compile-time)
config :architecture_generator, :file_storage, :local
config :architecture_generator, :uploads_bucket, "architecture-generator-uploads"

config :architecture_generator, Oban,
  repo: ArchitectureGenerator.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
