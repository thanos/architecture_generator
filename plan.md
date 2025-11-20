# Architecture Generator - Detailed Implementation Plan

## Overview
A sophisticated Phoenix LiveView application for translating Business Requirement Documents (BRDs) 
into formalized IT Architectural Plans (APs) via LLM integration with a multi-step workflow.

## Status Legend
- [x] Completed
- [ ] Pending

## Implementation Steps

### Phase 1: Project Setup ✅
- [x] Generate Phoenix app with SQLite
- [x] Create detailed plan.md
- [x] Start development server

### Phase 2: Database Schema & Migrations (3 steps)
- [ ] Create migration for projects and architectural_plans tables
  - projects table fields:
    - name (string)
    - brd_content (text)
    - brd_file_path (string, nullable)
    - status (string) - values: Initial, Elicitation, Tech_Stack_Input, Queued, Complete, Error
    - elicitation_data (map/json)
    - tech_stack_config (map/json)
    - llm_job_id (integer, nullable)
    - architectural_plan_id (references architectural_plans, nullable)
    - user_email (string)
    - timestamps
  - architectural_plans table fields:
    - project_id (references projects)
    - content (text) - full markdown AP
    - generated_at (naive_datetime)
    - timestamps

- [ ] Create Project schema (lib/architecture_generator/projects/project.ex)
  - Ecto schema with all fields
  - Status state machine validations
  - Changesets for each step transition
  - belongs_to :architectural_plan association

- [ ] Create ArchitecturalPlan schema (lib/architecture_generator/plans/architectural_plan.ex)
  - Ecto schema with project relationship
  - has_one :project association
  - Validation for content presence

### Phase 3: Core Context Modules (2 steps)
- [ ] Create Projects context (lib/architecture_generator/projects.ex)
  - create_project/1
  - get_project!/1
  - update_project_status/2
  - save_elicitation_data/2
  - save_tech_stack_config/2
  - list_projects/0

- [ ] Create Plans context (lib/architecture_generator/plans.ex)
  - create_architectural_plan/2
  - get_plan_by_project!/1

### Phase 4: External Dependencies Setup (3 steps)
- [ ] Add Oban dependency to mix.exs
  - {:oban, "~> 2.18"}
  - Run mix deps.get

- [ ] Configure Oban in application.ex supervision tree
  - Add Oban config to config/config.exs
  - Add Oban to children list in application.ex

- [ ] Add file upload dependency
  - Use Phoenix built-in upload handling

### Phase 5: LiveView Multi-Step Flow (6 steps)
- [ ] Create ProjectLive.Show module (lib/architecture_generator_web/live/project_live/show.ex)
  - Mount function loading project by ID
  - Handle allow_upload for BRD file
  - Status-based component rendering logic
  - Handle events for each step transition

- [ ] Create Step 1: Initial component (lib/architecture_generator_web/live/project_live/initial_step.ex)
  - Project name input
  - User email input
  - File upload component for BRD
  - Large textarea for BRD paste
  - "Generate Plan" button → transition to Elicitation

- [ ] Create Step 2: Elicitation component (lib/architecture_generator_web/live/project_live/elicitation_step.ex)
  - On entry: trigger ElicitationAnalyzer.run(project) async task
  - Display loading state while analyzing
  - Dynamic form rendering based on derived questions
  - Save answers to elicitation_data map
  - "Continue to Stack Selection" button → transition to Tech_Stack_Input

- [ ] Create Step 3: Tech Stack component (lib/architecture_generator_web/live/project_live/tech_stack_step.ex)
  - Form fields:
    - Primary Language (select: Python, Java, Go, Elixir, Node.js, Ruby)
    - Web Framework (conditional based on language)
    - Database System (select: PostgreSQL, MongoDB, MySQL, Cassandra, Redis)
    - Deployment Environment (select: AWS, Azure, GCP, On-Premise, Kubernetes)
  - Save to tech_stack_config map
  - "Submit for Final Generation" button → transition to Queued & enqueue Oban job

- [ ] Create Step 4: Queued component (lib/architecture_generator_web/live/project_live/queued_step.ex)
  - Display "Generating your Architectural Plan..." message
  - Show job_id and estimated time (up to 20 minutes)
  - Poll for status updates via handle_info

- [ ] Create Step 5: Complete component (lib/architecture_generator_web/live/project_live/complete_step.ex)
  - Display success message
  - Link to view full Architectural Plan
  - Download button for markdown export

### Phase 6: Elicitation Analyzer (1 step)
- [ ] Create ElicitationAnalyzer module (lib/architecture_generator/elicitation_analyzer.ex)
  - run/1 function that analyzes BRD content
  - Returns list of probing questions based on common ambiguities:
    - Performance requirements (RTO/RPO, TPS, latency)
    - Scalability expectations (concurrent users, data volume)
    - Security/compliance needs
    - Integration requirements
    - Deployment constraints
  - Initially can use rule-based heuristics, later enhance with LLM

### Phase 7: Background Processing with Oban (2 steps)
- [ ] Create ArchitectureGenerator.Worker module (lib/architecture_generator/workers/architecture_generator_worker.ex)
  - Oban worker that processes project
  - perform/1 function:
    1. Fetch project with all data
    2. Build comprehensive prompt from BRD + elicitation + tech_stack
    3. Call LLMAgent.generate_architectural_plan/1
    4. Create ArchitecturalPlan record with response
    5. Update project status to Complete
    6. Call Notification.deliver_report_ready/1
  - Handle errors and set status to Error

- [ ] Create LLMAgent service (lib/architecture_generator/services/llm_agent.ex)
  - generate_architectural_plan/1 function
  - Use Req library (already included) for HTTP calls
  - Integration with Google Gemini API
  - Construct prompt following canonical blueprint structure:
    - I. Architectural Foundations
    - II. Requirements Elicitation
    - III. Comprehensive IT Architectural Plan
    - V. Governance
  - API key from config/runtime.exs
  - Parse and return markdown response

### Phase 8: Notification System (2 steps)
- [ ] Configure Swoosh in config files
  - config/config.exs for general settings
  - config/dev.exs for local adapter
  - config/runtime.exs for production SMTP settings

- [ ] Create Notification module (lib/architecture_generator/notification.ex)
  - deliver_report_ready/1 function
  - Email template with project name and plan link
  - Use Swoosh to send email to project.user_email

### Phase 9: UI Design & Polish (3 steps)
- [ ] Replace home.html.heex with static design mockup
  - Modern SaaS design with gradients
  - Hero section explaining the tool
  - Call-to-action to create first project
  - Feature highlights

- [ ] Update app.css with Modern SaaS theme
  - Vibrant gradient backgrounds
  - Sleek color palette (purples, blues, teals)
  - Smooth transitions and shadows
  - Glassmorphism effects

- [ ] Update layouts (root.html.heex and Layouts.app)
  - Match Modern SaaS aesthetic
  - Clean navigation
  - Force light theme with vibrant accents
  - Remove default Phoenix header

### Phase 10: Routing & Integration (2 steps)
- [ ] Update router with project routes
  - Replace default "/" route
  - Add live "/projects/new", ProjectLive.New
  - Add live "/projects/:id", ProjectLive.Show

- [ ] Create ProjectLive.New for project creation
  - Simple form to create initial project
  - Redirect to ProjectLive.Show after creation

### Phase 11: Testing & Verification (2 steps)
- [ ] Visit the running app and test complete flow
  - Create project
  - Upload/paste BRD
  - Answer elicitation questions
  - Select tech stack
  - Verify background job processing
  - Check final AP generation

- [ ] Reserved for debugging and refinements

## Technical Notes

### File Upload Handling
- Use Phoenix.LiveView.allow_upload/3
- Accept .txt, .md, .pdf, .docx files
- Store uploaded files in priv/static/uploads
- Save file path to brd_file_path

### State Machine
Project status transitions:
Initial → Elicitation → Tech_Stack_Input → Queued → Complete
                                                   ↓
                                                 Error

### LLM Integration
- Primary: Google Gemini API (gemini-pro model)
- Fallback: Can be configured for other providers
- Store API key in config/runtime.exs: GEMINI_API_KEY

### Oban Configuration
- Use SQLite as queue storage
- Max 5 concurrent jobs
- Retry failed jobs 3 times with exponential backoff

