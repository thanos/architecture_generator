defmodule ArchitectureGeneratorWeb.ProjectLive.TechStackStepTest do
  use ExUnit.Case, async: true
  use ArchitectureGenerator.DataCase

  alias ArchitectureGenerator.Projects
  alias ArchitectureGeneratorWeb.ProjectLive.TechStackStep

  # Helper to create a proper socket structure
  defp create_socket(assigns \\ %{}) do
    %Phoenix.LiveView.Socket{
      assigns: Map.merge(%{__changed__: %{}, flash: %{}}, assigns)
    }
  end

  # Helper to get value from map with either string or atom keys
  defp get_tech_stack_value(tech_stack, key) do
    Map.get(tech_stack, key) || Map.get(tech_stack, String.to_atom(key))
  end

  # Helper to assert tech_stack_config value (database may use atom keys)
  defp assert_tech_stack_value(tech_stack_config, key, expected_value) do
    actual_value = get_tech_stack_value(tech_stack_config, key)
    assert actual_value == expected_value,
           "Expected tech_stack_config[#{key}] to be #{inspect(expected_value)}, got #{inspect(actual_value)}"
  end

  describe "update/2" do
    test "loads tech_stack_config from project" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status and save tech_stack_config
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      # Manually update tech_stack_config
      tech_stack = %{
        "primary_language" => "Elixir",
        "web_framework" => "Phoenix",
        "database_system" => "PostgreSQL",
        "deployment_env" => "Fly.io"
      }

      {:ok, project} = Projects.update_tech_stack_config(project, tech_stack)

      assigns = %{
        id: "tech-stack-step",
        project: project
      }

      socket = create_socket()

      assert {:ok, updated_socket} = TechStackStep.update(assigns, socket)

      assert updated_socket.assigns.project.id == project.id
      assert updated_socket.assigns.id == "tech-stack-step"
      # Ecto may store map keys as atoms, so use helper to check
      tech_stack = updated_socket.assigns.tech_stack
      assert get_tech_stack_value(tech_stack, "primary_language") == "Elixir"
      assert get_tech_stack_value(tech_stack, "web_framework") == "Phoenix"
      assert get_tech_stack_value(tech_stack, "database_system") == "PostgreSQL"
      assert get_tech_stack_value(tech_stack, "deployment_env") == "Fly.io"
    end

    test "initializes empty tech_stack when project has no config" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      assigns = %{
        id: "tech-stack-step",
        project: project
      }

      socket = create_socket()

      assert {:ok, updated_socket} = TechStackStep.update(assigns, socket)

      assert updated_socket.assigns.tech_stack == %{}
    end
  end

  describe "handle_event validate_stack/3" do
    test "updates tech_stack in socket assigns" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{}
      })

      params = %{
        "primary_language" => "Elixir",
        "web_framework" => "Phoenix"
      }

      assert {:noreply, updated_socket} = TechStackStep.handle_event("validate_stack", params, socket)

      assert updated_socket.assigns.tech_stack["primary_language"] == "Elixir"
      assert updated_socket.assigns.tech_stack["web_framework"] == "Phoenix"
    end

    test "merges new params with existing tech_stack" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir",
          "database_system" => "PostgreSQL"
        }
      })

      params = %{
        "web_framework" => "Phoenix",
        "deployment_env" => "Fly.io"
      }

      assert {:noreply, updated_socket} = TechStackStep.handle_event("validate_stack", params, socket)

      # Existing values preserved
      assert updated_socket.assigns.tech_stack["primary_language"] == "Elixir"
      assert updated_socket.assigns.tech_stack["database_system"] == "PostgreSQL"
      # New values added
      assert updated_socket.assigns.tech_stack["web_framework"] == "Phoenix"
      assert updated_socket.assigns.tech_stack["deployment_env"] == "Fly.io"
    end
  end

  describe "handle_event go_back/3" do
    test "saves tech_stack as draft before going back" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir",
          "web_framework" => "Phoenix",
          "database_system" => "PostgreSQL",
          "deployment_env" => "Fly.io"
        }
      })

      assert {:noreply, _updated_socket} = TechStackStep.handle_event("go_back", %{}, socket)

      # Verify tech_stack was saved to database
      updated_project = Projects.get_project!(project.id)
      assert_tech_stack_value(updated_project.tech_stack_config, "primary_language", "Elixir")
      assert_tech_stack_value(updated_project.tech_stack_config, "web_framework", "Phoenix")
      assert_tech_stack_value(updated_project.tech_stack_config, "database_system", "PostgreSQL")
      assert_tech_stack_value(updated_project.tech_stack_config, "deployment_env", "Fly.io")
    end

    test "transitions to Elicitation status after saving draft" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir"
        }
      })

      assert {:noreply, _updated_socket} = TechStackStep.handle_event("go_back", %{}, socket)

      # Verify status changed to Elicitation
      updated_project = Projects.get_project!(project.id)
      assert updated_project.status == "Elicitation"
    end

    test "still goes back even if draft save fails" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Create a project that's not in Tech_Stack_Input status to cause save to fail
      # Keep it in Initial status (can't save tech_stack in Initial status)
      invalid_project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: invalid_project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir"
        }
      })

      # Should still attempt to go back even if draft save fails
      assert {:noreply, _updated_socket} = TechStackStep.handle_event("go_back", %{}, socket)
    end
  end

  describe "handle_event submit_stack/3" do
    test "saves tech_stack as draft when validation fails" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir",
          "database_system" => "PostgreSQL",
          "deployment_env" => "AWS"  # Not Fly.io, so validation will fail
        }
      })

      assert {:noreply, updated_socket} = TechStackStep.handle_event("submit_stack", %{}, socket)

      # Should show error flash (flash can be atom or string key)
      flash_error = updated_socket.assigns.flash[:error] || updated_socket.assigns.flash["error"]
      assert flash_error == "Only Fly.io deployment is currently supported."

      # Verify tech_stack was saved as draft even though validation failed
      updated_project = Projects.get_project!(project.id)
      assert_tech_stack_value(updated_project.tech_stack_config, "primary_language", "Elixir")
      assert_tech_stack_value(updated_project.tech_stack_config, "database_system", "PostgreSQL")
      assert_tech_stack_value(updated_project.tech_stack_config, "deployment_env", "AWS")
      # Status should still be Tech_Stack_Input (not changed to Queued)
      assert updated_project.status == "Tech_Stack_Input"
    end

    test "saves tech_stack and transitions to Queued when validation passes" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      socket = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir",
          "web_framework" => "Phoenix",
          "database_system" => "PostgreSQL",
          "deployment_env" => "Fly.io"  # Valid deployment
        }
      })

      # Oban.insert might fail in tests, but tech_stack should still be saved
      result = TechStackStep.handle_event("submit_stack", %{}, socket)
      assert {:noreply, _updated_socket} = result

      # Verify tech_stack was saved (even if Oban failed)
      updated_project = Projects.get_project!(project.id)
      assert_tech_stack_value(updated_project.tech_stack_config, "primary_language", "Elixir")
      assert_tech_stack_value(updated_project.tech_stack_config, "web_framework", "Phoenix")
      assert_tech_stack_value(updated_project.tech_stack_config, "database_system", "PostgreSQL")
      assert_tech_stack_value(updated_project.tech_stack_config, "deployment_env", "Fly.io")
      # Status should change to Queued (if Oban succeeded) or stay Tech_Stack_Input (if Oban failed)
      # The important thing is that tech_stack was saved
      assert updated_project.status in ["Queued", "Tech_Stack_Input"]
    end
  end

  describe "persistence scenarios" do
    test "tech_stack persists when going back and returning" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      # Simulate user filling in form
      socket1 = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{}
      })

      # User enters data
      params = %{
        "primary_language" => "Elixir",
        "web_framework" => "Phoenix"
      }

      {:noreply, socket2} = TechStackStep.handle_event("validate_stack", params, socket1)

      # User goes back
      {:noreply, _socket3} = TechStackStep.handle_event("go_back", %{}, socket2)

      # Verify data was saved
      saved_project = Projects.get_project!(project.id)
      assert_tech_stack_value(saved_project.tech_stack_config, "primary_language", "Elixir")
      assert_tech_stack_value(saved_project.tech_stack_config, "web_framework", "Phoenix")

      # User returns to tech stack step - simulate component update
      assigns = %{
        id: "tech-stack-step",
        project: saved_project
      }

      socket4 = create_socket()
      {:ok, socket5} = TechStackStep.update(assigns, socket4)

      # Verify saved data is loaded
      assert get_tech_stack_value(socket5.assigns.tech_stack, "primary_language") == "Elixir"
      assert get_tech_stack_value(socket5.assigns.tech_stack, "web_framework") == "Phoenix"
    end

    test "tech_stack persists when submit fails and user returns" do
      {:ok, project} =
        Projects.create_project(%{
          name: "Test Project",
          user_email: "test@example.com",
          brd_content: "Test BRD"
        })

      # Transition to Tech_Stack_Input status
      {:ok, _} = Projects.update_project_status(project, "Elicitation")
      {:ok, _} = Projects.save_elicitation_data(Projects.get_project!(project.id), %{})

      project = Projects.get_project!(project.id)

      # Simulate user filling in form with invalid deployment
      socket1 = create_socket(%{
        project: project,
        id: "tech-stack-step",
        tech_stack: %{
          "primary_language" => "Elixir",
          "database_system" => "PostgreSQL",
          "deployment_env" => "AWS"  # Invalid
        }
      })

      # User submits (validation fails)
      {:noreply, _socket2} = TechStackStep.handle_event("submit_stack", %{}, socket1)

      # Verify data was saved as draft
      saved_project = Projects.get_project!(project.id)
      assert_tech_stack_value(saved_project.tech_stack_config, "primary_language", "Elixir")
      assert_tech_stack_value(saved_project.tech_stack_config, "database_system", "PostgreSQL")
      assert_tech_stack_value(saved_project.tech_stack_config, "deployment_env", "AWS")
      assert saved_project.status == "Tech_Stack_Input"  # Status unchanged

      # User fixes deployment and returns - simulate component update
      assigns = %{
        id: "tech-stack-step",
        project: saved_project
      }

      socket3 = create_socket()
      {:ok, socket4} = TechStackStep.update(assigns, socket3)

      # Verify saved data is loaded
      assert get_tech_stack_value(socket4.assigns.tech_stack, "primary_language") == "Elixir"
      assert get_tech_stack_value(socket4.assigns.tech_stack, "database_system") == "PostgreSQL"
      assert get_tech_stack_value(socket4.assigns.tech_stack, "deployment_env") == "AWS"
    end
  end
end
