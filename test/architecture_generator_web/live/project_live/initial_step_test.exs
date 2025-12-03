defmodule ArchitectureGeneratorWeb.ProjectLive.InitialStepTest do
  use ExUnit.Case, async: true
  use ArchitectureGenerator.DataCase

  alias ArchitectureGenerator.Projects
  alias ArchitectureGeneratorWeb.ProjectLive.InitialStep

  # Helper to create a proper socket structure
  defp create_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}}, assigns)
    }
  end

  describe "update/2" do
    test "handles full update with project" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      assigns = %{
        id: "initial-step",
        project: project,
        uploads: %{}
      }

      socket = create_socket()

      assert {:ok, updated_socket} = InitialStep.update(assigns, socket)

      assert updated_socket.assigns.project == project
      assert updated_socket.assigns.id == "initial-step"
      assert updated_socket.assigns.brd_text == "Test BRD content"
      assert updated_socket.assigns.processing_mode == "parse_only"
      assert updated_socket.assigns.llm_provider == "openai"
      # Verify parsing_status and parsed_content_preview are initialized to nil
      assert updated_socket.assigns.parsing_status == nil
      assert updated_socket.assigns.parsed_content_preview == nil
    end

    test "handles partial update with only parsing_status" do
      # This tests the bug fix - partial updates without project should not crash
      assigns = %{
        id: "initial-step",
        parsing_status: "Processing file.pdf..."
      }

      socket = create_socket(%{
        project: %Projects.Project{
          id: 1,
          name: "Existing Project",
          brd_content: "Existing content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        },
        id: "initial-step",
        brd_text: "Existing content",
        processing_mode: "parse_only",
        llm_provider: "openai"
      })

      assert {:ok, updated_socket} = InitialStep.update(assigns, socket)

      # Should preserve existing project data
      assert updated_socket.assigns.project.name == "Existing Project"
      assert updated_socket.assigns.brd_text == "Existing content"

      # Should update parsing_status
      assert updated_socket.assigns.parsing_status == "Processing file.pdf..."
    end

    test "handles partial update with only parsed_content_preview" do
      assigns = %{
        id: "initial-step",
        parsed_content_preview: "Preview of parsed content..."
      }

      socket = create_socket(%{
        project: %Projects.Project{
          id: 1,
          name: "Existing Project",
          brd_content: "Existing content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        },
        id: "initial-step",
        brd_text: "Existing content",
        processing_mode: "parse_only",
        llm_provider: "openai"
      })

      assert {:ok, updated_socket} = InitialStep.update(assigns, socket)

      # Should preserve existing project data
      assert updated_socket.assigns.project.name == "Existing Project"

      # Should update parsed_content_preview
      assert updated_socket.assigns.parsed_content_preview == "Preview of parsed content..."
    end

    test "handles partial update with both parsing_status and parsed_content_preview" do
      assigns = %{
        id: "initial-step",
        parsing_status: "✅ Successfully processed file.pdf",
        parsed_content_preview: "First 500 characters of content..."
      }

      socket = create_socket(%{
        project: %Projects.Project{
          id: 1,
          name: "Existing Project",
          brd_content: "Existing content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        },
        id: "initial-step",
        brd_text: "Existing content",
        processing_mode: "parse_only",
        llm_provider: "openai"
      })

      assert {:ok, updated_socket} = InitialStep.update(assigns, socket)

      # Should preserve existing project data
      assert updated_socket.assigns.project.name == "Existing Project"

      # Should update both fields
      assert updated_socket.assigns.parsing_status == "✅ Successfully processed file.pdf"
      assert updated_socket.assigns.parsed_content_preview == "First 500 characters of content..."
    end

    test "handles partial update with id only" do
      assigns = %{
        id: "initial-step"
      }

      socket = create_socket(%{
        project: %Projects.Project{
          id: 1,
          name: "Existing Project",
          brd_content: "Existing content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        },
        id: "old-id",
        brd_text: "Existing content",
        processing_mode: "parse_only",
        llm_provider: "openai"
      })

      assert {:ok, updated_socket} = InitialStep.update(assigns, socket)

      # Should update id
      assert updated_socket.assigns.id == "initial-step"

      # Should preserve existing project data
      assert updated_socket.assigns.project.name == "Existing Project"
    end

    test "does not crash when project is missing in partial update" do
      # This is the specific bug we fixed - send_update with only parsing_status
      # should not try to access assigns.project
      assigns = %{
        id: "initial-step",
        parsing_status: "Processing file.pdf..."
      }

      socket = create_socket(%{
        id: "initial-step"
      })

      # Should not raise KeyError
      assert {:ok, _updated_socket} = InitialStep.update(assigns, socket)
    end
  end
end
