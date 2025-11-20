import Config

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :architecture_generator, ArchitectureGenerator.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "architecture_generator_test#{System.get_env("MIX_TEST_PARTITION")}",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :architecture_generator, ArchitectureGeneratorWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "ODdCMxt3w4xkQ/1KSrGORwirHJ+7Uequtxbs3xjW+U0L/7lUxDOYJm3FDikPmUHJ",
  server: false

# In test we don't send emails
config :architecture_generator, ArchitectureGenerator.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
