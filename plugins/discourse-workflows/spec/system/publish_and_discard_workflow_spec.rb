# frozen_string_literal: true

RSpec.describe "Publish and discard a workflow" do
  fab!(:admin)

  let(:settings_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowSettings.new }
  let(:editor_page) { PageObjects::Pages::DiscourseWorkflows::WorkflowEditor.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(admin) }

  context "when acting from the Settings page" do
    fab!(:workflow) { Fabricate(:discourse_workflows_workflow, created_by: admin, published: true) }

    before { workflow.snapshot!(user: admin) }

    it "lets an admin publish pending changes" do
      settings_page.visit(workflow.id)
      expect(settings_page).to have_publish_notice

      settings_page.click_publish
      expect(settings_page).to have_no_publish_notice

      page.refresh
      expect(settings_page).to have_no_publish_notice
    end

    it "lets an admin discard pending changes" do
      settings_page.visit(workflow.id)
      expect(settings_page).to have_publish_notice

      settings_page.click_discard
      dialog.click_yes

      expect(settings_page).to have_no_publish_notice

      page.refresh
      expect(settings_page).to have_no_publish_notice
    end
  end

  context "when acting from the canvas" do
    fab!(:workflow) do
      graph = build_workflow_graph { |g| g.node "trigger-1", "trigger:manual" }
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    it "lets an admin publish pending canvas changes" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "trigger-2", "trigger:schedule"
        end
      workflow.update!(nodes: graph[:nodes], connections: graph[:connections])
      workflow.snapshot!(user: admin)

      editor_page.visit(workflow.id)
      expect(editor_page).to have_publish_banner
      expect(editor_page).to have_node_count(2)

      editor_page.click_publish
      expect(editor_page).to have_no_publish_banner

      page.refresh
      expect(editor_page).to have_node_count(2)
    end

    it "lets an admin discard pending canvas changes and restores the published graph" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "trigger-2", "trigger:schedule"
        end
      workflow.update!(nodes: graph[:nodes], connections: graph[:connections])
      workflow.snapshot!(user: admin)

      editor_page.visit(workflow.id)
      expect(editor_page).to have_node_count(2)

      editor_page.click_discard
      dialog.click_yes

      expect(editor_page).to have_no_publish_banner
      expect(editor_page).to have_node_count(1)

      page.refresh
      expect(editor_page).to have_node_count(1)
    end
  end
end
