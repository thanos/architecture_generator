defmodule ArchitectureGeneratorWeb.LiveViewCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a LiveView connection.

  Such tests rely on `Phoenix.LiveViewTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # Import conveniences for testing with connections
      import Phoenix.ConnTest
      import Phoenix.LiveViewTest
      import ArchitectureGeneratorWeb.ConnCase
      import ArchitectureGenerator.DataCase
    end
  end

  setup tags do
    ArchitectureGenerator.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end
end
