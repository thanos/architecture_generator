defmodule ArchitectureGeneratorWeb.ProjectLive.InitialStepTest do
  use ExUnit.Case, async: true
  use ArchitectureGenerator.DataCase

  alias ArchitectureGenerator.Projects
  alias ArchitectureGeneratorWeb.ProjectLive.InitialStep

  # Helper to create a proper socket structure
  defp create_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}, flash: %{}}, assigns)
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

  describe "handle_event validate_brd/3" do
    test "saves brd_text as draft to database" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Initial content"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Initial content",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      new_brd_text = "Updated BRD content with more details about the project requirements"

      assert {:noreply, updated_socket} =
               InitialStep.handle_event("validate_brd", %{"brd_text" => new_brd_text}, socket)

      # Verify socket was updated
      assert updated_socket.assigns.brd_text == new_brd_text

      # Verify database was updated
      updated_project = Projects.get_project!(project.id)
      assert updated_project.brd_content == new_brd_text
    end

    test "preserves processing_mode and llm_provider when saving brd_text" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          processing_mode: "llm_parsed",
          llm_provider: "openai"
        })

      # Reload to get the actual values from database
      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: project.processing_mode || "parse_only",
        llm_provider: project.llm_provider || "openai",
        flash: %{}
      })

      new_brd_text = "New BRD content"

      assert {:noreply, _updated_socket} =
               InitialStep.handle_event("validate_brd", %{"brd_text" => new_brd_text}, socket)

      # Verify processing_mode and llm_provider are preserved
      updated_project = Projects.get_project!(project.id)
      assert updated_project.brd_content == new_brd_text
      # The changeset should preserve existing values when only brd_content is updated
      assert updated_project.processing_mode == "llm_parsed"
      assert updated_project.llm_provider == "openai"
    end
  end

  describe "handle_event validate_processing_mode/3" do
    test "saves processing_mode and llm_provider as draft to database" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Some BRD content",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      params = %{
        "processing_mode" => "llm_parsed",
        "llm_provider" => "openai"
      }

      assert {:noreply, updated_socket} =
               InitialStep.handle_event("validate_processing_mode", params, socket)

      # Verify socket was updated
      assert updated_socket.assigns.processing_mode == "llm_parsed"
      assert updated_socket.assigns.llm_provider == "openai"

      # Verify database was updated
      updated_project = Projects.get_project!(project.id)
      assert updated_project.processing_mode == "llm_parsed"
      assert updated_project.llm_provider == "openai"
    end

    test "preserves brd_content when saving processing_mode" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Existing BRD content",
          processing_mode: "parse_only"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Existing BRD content",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      params = %{
        "processing_mode" => "llm_raw",
        "llm_provider" => "openai"
      }

      assert {:noreply, _updated_socket} =
               InitialStep.handle_event("validate_processing_mode", params, socket)

      # Verify brd_content is preserved
      updated_project = Projects.get_project!(project.id)
      assert updated_project.brd_content == "Existing BRD content"
      assert updated_project.processing_mode == "llm_raw"
    end

    test "uses default values when params are missing" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # Empty params should use defaults
      assert {:noreply, updated_socket} =
               InitialStep.handle_event("validate_processing_mode", %{}, socket)

      # Should use defaults
      assert updated_socket.assigns.processing_mode == "parse_only"
      assert updated_socket.assigns.llm_provider == "openai"
    end
  end

  describe "persistence scenarios" do
    test "brd_text persists when user navigates away and returns" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com"
        })

      # Simulate user entering text
      socket1 = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      user_input = "This is my BRD content with detailed requirements"

      {:noreply, _socket2} =
        InitialStep.handle_event("validate_brd", %{"brd_text" => user_input}, socket1)

      # Verify data was saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == user_input

      # Simulate user navigating back to the step - component update
      assigns = %{
        id: "initial-step",
        project: saved_project
      }

      socket3 = create_socket()
      {:ok, socket4} = InitialStep.update(assigns, socket3)

      # Verify saved data is loaded
      assert socket4.assigns.brd_text == user_input
    end

    test "processing_mode and llm_provider persist when user navigates away and returns" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com"
        })

      # Simulate user selecting processing mode
      socket1 = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      params = %{
        "processing_mode" => "llm_parsed",
        "llm_provider" => "openai"
      }

      {:noreply, _socket2} =
        InitialStep.handle_event("validate_processing_mode", params, socket1)

      # Verify data was saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"

      # Simulate user navigating back to the step - component update
      assigns = %{
        id: "initial-step",
        project: saved_project
      }

      socket3 = create_socket()
      {:ok, socket4} = InitialStep.update(assigns, socket3)

      # Verify saved data is loaded
      assert socket4.assigns.processing_mode == "llm_parsed"
      assert socket4.assigns.llm_provider == "openai"
    end

    test "all inputs persist together when user makes multiple changes" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # User enters BRD text
      {:noreply, socket} =
        InitialStep.handle_event("validate_brd", %{"brd_text" => "My BRD content"}, socket)

      # User changes processing mode
      {:noreply, socket} =
        InitialStep.handle_event(
          "validate_processing_mode",
          %{"processing_mode" => "llm_raw", "llm_provider" => "openai"},
          socket
        )

      # User updates BRD text again
      {:noreply, _socket} =
        InitialStep.handle_event("validate_brd", %{"brd_text" => "Updated BRD content"}, socket)

      # Verify all changes were saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Updated BRD content"
      assert saved_project.processing_mode == "llm_raw"
      assert saved_project.llm_provider == "openai"

      # Simulate user navigating back - component update
      assigns = %{
        id: "initial-step",
        project: saved_project
      }

      new_socket = create_socket()
      {:ok, updated_socket} = InitialStep.update(assigns, new_socket)

      # Verify all saved data is loaded
      assert updated_socket.assigns.brd_text == "Updated BRD content"
      assert updated_socket.assigns.processing_mode == "llm_raw"
      assert updated_socket.assigns.llm_provider == "openai"
    end

    test "inputs persist even when status changes (e.g., going back from Elicitation)" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Original BRD",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      # User is at Elicitation step, then goes back
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      project = Projects.get_project!(project.id)

      # User goes back to Initial step
      {:ok, _} = Projects.go_back_to_status(project, "Initial")
      project = Projects.get_project!(project.id)

      # User updates inputs
      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: project.brd_content || "",
        processing_mode: project.processing_mode || "parse_only",
        llm_provider: project.llm_provider || "openai",
        flash: %{}
      })

      {:noreply, _socket} =
        InitialStep.handle_event("validate_brd", %{"brd_text" => "Updated after going back"}, socket)

      {:noreply, _socket} =
        InitialStep.handle_event(
          "validate_processing_mode",
          %{"processing_mode" => "llm_parsed", "llm_provider" => "openai"},
          socket
        )

      # Verify inputs were saved even though status changed
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Updated after going back"
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"
      assert saved_project.status == "Initial" # Status should still be Initial
    end

    test "processing_mode and llm_provider persist when file is uploaded" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # User sets processing mode
      socket1 = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Test BRD",
        processing_mode: "llm_parsed",
        llm_provider: "openai",
        flash: %{}
      })

      {:noreply, socket2} =
        InitialStep.handle_event(
          "validate_processing_mode",
          %{"processing_mode" => "llm_parsed", "llm_provider" => "openai"},
          socket1
        )

      # Verify they were saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"

      # Simulate file upload - validate_upload should save the values again
      {:noreply, _socket3} = InitialStep.handle_event("validate_upload", %{}, socket2)

      # Verify they're still saved after file upload
      saved_project2 = Projects.get_project!(project.id)
      assert saved_project2.processing_mode == "llm_parsed"
      assert saved_project2.llm_provider == "openai"
    end

    test "processing_mode and llm_provider are preserved when component is updated after file upload" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD",
          processing_mode: "llm_raw",
          llm_provider: "openai"
        })

      # User changes processing_mode - this should save to database immediately
      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Test BRD",
        processing_mode: "llm_raw",
        llm_provider: "openai",
        flash: %{}
      })

      # User changes processing mode - this triggers validate_form which saves to database
      {:noreply, _socket} =
        InitialStep.handle_event(
          "validate_form",
          %{"processing_mode" => "llm_parsed", "llm_provider" => "openai"},
          socket
        )

      # Verify it was saved to database
      saved_project = Projects.get_project!(project.id)
      assert saved_project.processing_mode == "llm_parsed"

      # Simulate component update (e.g., after project refresh)
      # The component should load from database, which now has "llm_parsed"
      assigns = %{
        id: "initial-step",
        project: saved_project  # Project from database now has "llm_parsed"
      }

      {:ok, updated_socket} = InitialStep.update(assigns, create_socket())

      # Should load from database (llm_parsed)
      assert updated_socket.assigns.processing_mode == "llm_parsed"
      assert updated_socket.assigns.llm_provider == "openai"
    end
  end

  describe "validate_form - unified form validation" do
    test "saves all form values together when only brd_text changes" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Initial BRD",
          processing_mode: "llm_parsed",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Initial BRD",
        processing_mode: "llm_parsed",
        llm_provider: "openai",
        flash: %{}
      })

      # User changes only brd_text
      {:noreply, updated_socket} =
        InitialStep.handle_event("validate_form", %{"brd_text" => "Updated BRD content"}, socket)

      # Verify socket was updated
      assert updated_socket.assigns.brd_text == "Updated BRD content"

      # Verify ALL values were saved to database (including processing_mode and llm_provider)
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Updated BRD content"
      assert saved_project.processing_mode == "llm_parsed"  # Preserved from socket
      assert saved_project.llm_provider == "openai"  # Preserved from socket
    end

    test "saves all form values together when only processing_mode changes" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "My BRD content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "My BRD content",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # User changes only processing_mode
      {:noreply, updated_socket} =
        InitialStep.handle_event(
          "validate_form",
          %{"processing_mode" => "llm_raw", "llm_provider" => "openai"},
          socket
        )

      # Verify socket was updated
      assert updated_socket.assigns.processing_mode == "llm_raw"

      # Verify ALL values were saved to database (including brd_text)
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "My BRD content"  # Preserved from socket
      assert saved_project.processing_mode == "llm_raw"
      assert saved_project.llm_provider == "openai"
    end

    test "saves all form values together when all fields change" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Old BRD",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Old BRD",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # User changes all fields at once
      {:noreply, updated_socket} =
        InitialStep.handle_event(
          "validate_form",
          %{
            "brd_text" => "New BRD content",
            "processing_mode" => "llm_parsed",
            "llm_provider" => "openai"
          },
          socket
        )

      # Verify socket was updated
      assert updated_socket.assigns.brd_text == "New BRD content"
      assert updated_socket.assigns.processing_mode == "llm_parsed"
      assert updated_socket.assigns.llm_provider == "openai"

      # Verify all values were saved to database
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "New BRD content"
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"
    end

    test "preserves existing values when only one field is in params" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Existing BRD",
          processing_mode: "llm_parsed",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Existing BRD",
        processing_mode: "llm_parsed",
        llm_provider: "openai",
        flash: %{}
      })

      # User changes only processing_mode (no brd_text in params)
      {:noreply, _updated_socket} =
        InitialStep.handle_event(
          "validate_form",
          %{"processing_mode" => "llm_raw"},
          socket
        )

      # Verify brd_text was preserved (from socket assigns)
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Existing BRD"
      assert saved_project.processing_mode == "llm_raw"
      assert saved_project.llm_provider == "openai"  # Preserved from socket
    end

    test "validate_upload saves all form values" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "My BRD",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "My BRD",
        processing_mode: "llm_parsed",  # User changed this
        llm_provider: "openai",
        flash: %{}
      })

      # Simulate file upload - should save all current form values
      {:noreply, _updated_socket} = InitialStep.handle_event("validate_upload", %{}, socket)

      # Verify all values were saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "My BRD"
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"
    end

    test "component update loads latest saved values from database" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Initial content",
          processing_mode: "parse_only",
          llm_provider: "openai"
        })

      # User changes values via validate_form
      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Initial content",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      {:noreply, _socket} =
        InitialStep.handle_event(
          "validate_form",
          %{
            "brd_text" => "Updated content",
            "processing_mode" => "llm_raw",
            "llm_provider" => "openai"
          },
          socket
        )

      # Verify values were saved
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Updated content"
      assert saved_project.processing_mode == "llm_raw"

      # Simulate component update (e.g., after project refresh)
      assigns = %{
        id: "initial-step",
        project: saved_project
      }

      {:ok, updated_socket} = InitialStep.update(assigns, create_socket())

      # Should load the latest saved values from database
      assert updated_socket.assigns.brd_text == "Updated content"
      assert updated_socket.assigns.processing_mode == "llm_raw"
      assert updated_socket.assigns.llm_provider == "openai"
    end

    test "backward compatibility - validate_brd routes to validate_form" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          processing_mode: "llm_parsed",
          llm_provider: "openai"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "llm_parsed",
        llm_provider: "openai",
        flash: %{}
      })

      # Using old handler name should still work
      {:noreply, _updated_socket} =
        InitialStep.handle_event("validate_brd", %{"brd_text" => "New BRD"}, socket)

      # Verify all values were saved (not just brd_text)
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "New BRD"
      assert saved_project.processing_mode == "llm_parsed"  # Preserved
      assert saved_project.llm_provider == "openai"  # Preserved
    end

    test "backward compatibility - validate_processing_mode routes to validate_form" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Existing BRD"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "Existing BRD",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # Using old handler name should still work
      {:noreply, _updated_socket} =
        InitialStep.handle_event(
          "validate_processing_mode",
          %{"processing_mode" => "llm_parsed", "llm_provider" => "openai"},
          socket
        )

      # Verify all values were saved (not just processing_mode)
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Existing BRD"  # Preserved
      assert saved_project.processing_mode == "llm_parsed"
      assert saved_project.llm_provider == "openai"
    end

    test "multiple sequential changes all persist correctly" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com"
        })

      socket = create_socket(%{
        project: project,
        id: "initial-step",
        brd_text: "",
        processing_mode: "parse_only",
        llm_provider: "openai",
        flash: %{}
      })

      # User enters BRD text
      {:noreply, socket} =
        InitialStep.handle_event("validate_form", %{"brd_text" => "Step 1: BRD content"}, socket)

      # User changes processing mode
      {:noreply, socket} =
        InitialStep.handle_event(
          "validate_form",
          %{"processing_mode" => "llm_parsed", "llm_provider" => "openai"},
          socket
        )

      # User updates BRD text again
      {:noreply, socket} =
        InitialStep.handle_event("validate_form", %{"brd_text" => "Step 2: Updated BRD"}, socket)

      # User changes processing mode again
      {:noreply, _socket} =
        InitialStep.handle_event(
          "validate_form",
          %{"processing_mode" => "llm_raw", "llm_provider" => "openai"},
          socket
        )

      # Verify final state - all changes persisted
      saved_project = Projects.get_project!(project.id)
      assert saved_project.brd_content == "Step 2: Updated BRD"
      assert saved_project.processing_mode == "llm_raw"
      assert saved_project.llm_provider == "openai"
    end
  end
end
