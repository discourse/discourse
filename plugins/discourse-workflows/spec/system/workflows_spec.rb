# frozen_string_literal: true

RSpec.describe "Discourse Workflows" do
  fab!(:admin)

  let(:workflows_page) { PageObjects::Pages::Workflows.new }
  let(:editor_page) { PageObjects::Pages::WorkflowEditor.new }

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "creates a workflow with trigger and action" do
    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")

    expect(editor_page).to have_node_count(1)

    editor_page.click_add_node
    editor_page.select_node_type("action:topic_tags", operation: "add")

    expect(editor_page).to have_node_count(2)

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "creates a workflow with condition node" do
    editor_page.visit_new

    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")

    expect(editor_page).to have_node_count(1)

    editor_page.click_add_node
    editor_page.select_node_type("condition:if")

    expect(editor_page).to have_node_count(2)
    expect(editor_page).to have_node("If")

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "shows a warning icon when the latest workflow run failed" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :error,
      created_at: 1.hour.ago,
    )

    workflows_page.visit_index

    expect(workflows_page).to have_failed_workflow(workflow)
  end

  context "when closing the node configurator" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    before do
      workflow.update!(
        nodes: [
          {
            "id" => "trigger-1",
            "client_id" => "trigger-1",
            "type" => "trigger:manual",
            "type_version" => 1,
            "name" => "Manual trigger",
            "position" => {
              "x" => 100,
              "y" => 100,
            },
            "position_index" => 0,
            "configuration" => {},
          },
        ],
        connections: [],
      )
    end

    def count_workflow_updates
      count = 0
      subscriber =
        ActiveSupport::Notifications.subscribe("process_action.action_controller") do |*, payload|
          if payload[:controller] == "DiscourseWorkflows::WorkflowsController" &&
               payload[:action] == "update"
            count += 1
          end
        end
      begin
        yield
      ensure
        ActiveSupport::Notifications.unsubscribe(subscriber)
      end
      count
    end

    it "does not save the workflow when nothing changed" do
      updates =
        count_workflow_updates do
          editor_page.visit(workflow.id)
          expect(editor_page).to have_node_count(1)
          editor_page.double_click_node(0)
          expect(editor_page).to have_node_configurator
          editor_page.close_node_configurator
          expect(editor_page).to have_no_node_configurator
        end

      expect(updates).to eq(0)
    end
  end

  it "does not show a warning icon when a newer run succeeded" do
    workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :error,
      created_at: 2.hours.ago,
    )
    DiscourseWorkflows::Execution.create!(
      workflow: workflow,
      status: :success,
      created_at: 1.hour.ago,
    )

    workflows_page.visit_index

    expect(workflows_page).to have_no_failed_workflow(workflow)
  end
end
