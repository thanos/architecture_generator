defmodule ArchitectureGeneratorWeb.Router do
  use ArchitectureGeneratorWeb, :router

  import Oban.Web.Router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ArchitectureGeneratorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  pipeline :admin do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :put_root_layout, html: {ArchitectureGeneratorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :basic_auth
  end

  defp basic_auth(conn, _opts) do
    username = System.get_env("OBAN_WEB_USERNAME") || "admin"
    password = System.get_env("OBAN_WEB_PASSWORD") || "admin"

    Plug.BasicAuth.basic_auth(conn, username: username, password: password)
  end

  scope "/", ArchitectureGeneratorWeb do
    pipe_through :browser

    get "/", PageController, :home
    live "/projects", ProjectLive.Index, :index
    live "/projects/new", ProjectLive.New
    live "/projects/:id", ProjectLive.Show
    live "/uploads", UploadLive.Index, :index
    live "/uploads/:id", UploadLive.Show, :show
    live "/artifacts", ArtifactLive.Index, :index
    live "/artifacts/:id", ArtifactLive.Show, :show
  end

  # Oban Web Interface for monitoring background jobs
  scope "/admin" do
    pipe_through :admin

    oban_dashboard "/oban"
  end

  # Other scopes may use custom stacks.
  # scope "/api", ArchitectureGeneratorWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:architecture_generator, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ArchitectureGeneratorWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end
  end
end
