# frozen_string_literal: true

RSpec.describe "Discourse Workflows" do
  fab!(:admin)

  let(:workflows_page) { PageObjects::Pages::DiscourseWorkflows::Workflows.new }
  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }

  before do
    SiteSetting.tagging_enabled = true
    sign_in(admin)
  end

  it "creates a workflow with trigger and action" do
    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")
    editor_page.click_add_node
    editor_page.select_node_type("action:topic_tags", operation: "add")

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "creates a workflow with condition node" do
    editor_page.visit_new
    editor_page.click_empty_state_add_node
    editor_page.select_node_type("trigger:topic_closed")
    editor_page.click_add_node
    editor_page.select_node_type("condition:if")

    workflows_page.visit_index
    expect(workflows_page).to have_workflow("My workflow")
  end

  it "renders the failed-run warning icon based on the most recent execution" do
    failed_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)
    recovered_workflow = Fabricate(:discourse_workflows_workflow, created_by: admin)

    Fabricate(
      :discourse_workflows_error_execution,
      workflow: failed_workflow,
      created_at: 1.hour.ago,
    )
    Fabricate(
      :discourse_workflows_error_execution,
      workflow: recovered_workflow,
      created_at: 2.hours.ago,
    )
    Fabricate(
      :discourse_workflows_completed_execution,
      workflow: recovered_workflow,
      created_at: 1.hour.ago,
    )

    workflows_page.visit_index

    expect(workflows_page).to have_failed_workflow(failed_workflow)
    expect(workflows_page).to have_no_failed_workflow(recovered_workflow)
  end

  context "when closing the node configurator" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }

    before do
      workflow.update!(
        nodes: [
          {
            "id" => "trigger-1",
            "type" => "trigger:manual",
            "typeVersion" => "1.0",
            "name" => "Manual trigger",
            "position" => {
              "x" => 100,
              "y" => 100,
            },
            "parameters" => {
            },
            "credentials" => {
            },
          },
        ],
        connections: {
        },
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
end
