defmodule ArchitectureGeneratorWeb.PageController do
  use ArchitectureGeneratorWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
