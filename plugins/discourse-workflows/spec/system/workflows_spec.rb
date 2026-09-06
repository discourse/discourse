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

  context "with workflow tags" do
    fab!(:ops_workflow) do
      Fabricate(
        :discourse_workflows_workflow,
        name: "Ops workflow",
        created_by: admin,
        tags: %w[ops],
      )
    end
    fab!(:billing_workflow) do
      Fabricate(
        :discourse_workflows_workflow,
        name: "Billing workflow",
        created_by: admin,
        tags: %w[billing],
      )
    end

    it "filters the list by tag from a row chip and from the tag filter" do
      workflows_page.visit_index

      expect(workflows_page).to have_workflow_tag(ops_workflow, "ops")
      expect(workflows_page).to have_workflow_tag(billing_workflow, "billing")

      workflows_page.click_workflow_tag(ops_workflow, "ops")
      expect(workflows_page).to have_workflow("Ops workflow")
      expect(workflows_page).to have_no_workflow("Billing workflow")
      expect(page.current_url).to include("tags=ops")

      workflows_page.reset_filters
      expect(workflows_page).to have_workflow("Billing workflow")

      workflows_page.filter_by_tag("billing")
      expect(workflows_page).to have_workflow("Billing workflow")
      expect(workflows_page).to have_no_workflow("Ops workflow")
    end

    it "adds a tag from the editor header even when core tagging is disabled" do
      SiteSetting.tagging_enabled = false

      editor_page.visit(billing_workflow.id)
      editor_page.add_tag("urgent")

      expect(editor_page).to have_header_tag("urgent")
      expect(billing_workflow.reload.tags.map(&:name)).to eq(%w[billing urgent])

      workflows_page.visit_index
      expect(workflows_page).to have_workflow_tag(billing_workflow, "urgent")
    end
  end

  context "with a persisted workflow node" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin) }
    fab!(:unavailable_workflow) do
      Fabricate(
        :discourse_workflows_workflow,
        created_by: admin,
        nodes: [
          {
            "id" => "unavailable-1",
            "type" => "action:disabled_plugin_node",
            "typeVersion" => "1.0",
            "name" => "Unavailable node",
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

    let(:node_id) { "trigger.1" }

    before do
      workflow.update!(
        nodes: [
          {
            "id" => node_id,
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
          expect(editor_page).to have_workflow_path(workflow)

          editor_page.double_click_node(0)
          expect(editor_page).to have_node_configurator
          expect(editor_page).to have_node_path(workflow, node_id)

          editor_page.close_node_configurator
          expect(editor_page).to have_no_node_configurator
          expect(editor_page).to have_workflow_path(workflow)
        end

      expect(updates).to eq(0)
    end

    it "lets an admin reopen the same configured node after a refresh" do
      editor_page.visit_node(workflow, node_id)

      expect(editor_page).to have_node_path(workflow, node_id)
      expect(editor_page).to have_node_configurator(name: "Manual trigger")

      editor_page.rename_configured_node("Refreshable manual trigger")
      expect(editor_page).to have_saved_node_configuration

      page.refresh

      expect(editor_page).to have_node_path(workflow, node_id)
      expect(editor_page).to have_node_configurator(name: "Refreshable manual trigger")
    end

    it "returns an admin to the workflow when a linked node is missing or unavailable" do
      editor_page.visit_node(workflow, "missing-node")

      expect(editor_page).to have_workflow_path(workflow)
      expect(editor_page).to have_no_node_configurator

      editor_page.visit_node(unavailable_workflow, "unavailable-1")

      expect(editor_page).to have_workflow_path(unavailable_workflow)
      expect(editor_page).to have_no_node_configurator
    end
  end
end
