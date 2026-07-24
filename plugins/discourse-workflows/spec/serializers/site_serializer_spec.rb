# frozen_string_literal: true

RSpec.describe SiteSerializer do
  fab!(:admin)
  fab!(:moderator)
  fab!(:user)
  let(:guardian) { Guardian.new(admin) }

  describe "#topic_admin_button_workflows" do
    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    fab!(:workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:topic_admin_button",
                 configuration: {
                   "label" => "Run workflow",
                   "icon" => "bolt",
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    it "includes published topic admin button workflows" do
      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to contain_exactly(
        {
          trigger_node_id: "trigger-1",
          workflow_id: workflow.id,
          label: "Run workflow",
          icon: "bolt",
        },
      )
    end

    it "is not included for moderators" do
      mod_guardian = Guardian.new(moderator)
      data = described_class.new(Site.new(mod_guardian), scope: mod_guardian, root: false).as_json

      expect(data).not_to have_key(:topic_admin_button_workflows)
    end

    it "is not included for regular users" do
      user_guardian = Guardian.new(user)
      data = described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json

      expect(data).not_to have_key(:topic_admin_button_workflows)
    end

    it "keeps the icon empty when none is configured" do
      update_workflow_node(workflow, "trigger-1") do |node|
        node.merge("parameters" => { "label" => "Run workflow" })
      end
      publish_workflow!(workflow)

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows].first[:icon]).to be_nil
    end

    it "excludes unpublished workflows" do
      unpublish_workflow!(workflow)
      DiscourseWorkflows::WorkflowDependency.clear_cache!

      data = described_class.new(Site.new(guardian), scope: guardian, root: false).as_json

      expect(data[:topic_admin_button_workflows]).to be_empty
    end
  end

  describe "#post_button_workflows" do
    before { DiscourseWorkflows::WorkflowDependency.clear_cache! }

    fab!(:group)
    fab!(:member) { Fabricate(:user).tap { |member| group.add(member) } }

    fab!(:post_button_workflow) do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1",
                 "trigger:post_button",
                 configuration: {
                   "label" => "Run workflow",
                   "icon" => "bolt",
                   "group_ids" => [group.id],
                 }
        end
      Fabricate(:discourse_workflows_workflow, created_by: admin, published: true, **graph)
    end

    it "includes published post button workflows for group members without leaking group ids" do
      member_guardian = Guardian.new(member)
      data =
        described_class.new(Site.new(member_guardian), scope: member_guardian, root: false).as_json

      expect(data[:post_button_workflows]).to contain_exactly(
        {
          trigger_node_id: "trigger-1",
          workflow_id: post_button_workflow.id,
          label: "Run workflow",
          icon: "bolt",
          position: "last",
          confirmation: false,
          confirmation_message: nil,
        },
      )
    end

    it "returns an empty list for users in none of the configured groups" do
      user_guardian = Guardian.new(user)
      data = described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json

      expect(data[:post_button_workflows]).to be_empty
    end

    it "is not included for anonymous users" do
      anon_guardian = Guardian.new
      data = described_class.new(Site.new(anon_guardian), scope: anon_guardian, root: false).as_json

      expect(data).not_to have_key(:post_button_workflows)
    end

    it "is not included when no post button workflow is published" do
      unpublish_workflow!(post_button_workflow)
      DiscourseWorkflows::WorkflowDependency.clear_cache!

      member_guardian = Guardian.new(member)
      data =
        described_class.new(Site.new(member_guardian), scope: member_guardian, root: false).as_json

      expect(data).not_to have_key(:post_button_workflows)
    end

    it "returns an empty list for everyone when the trigger has no groups configured" do
      update_workflow_node(post_button_workflow, "trigger-1") do |node|
        node.merge("parameters" => { "label" => "Run workflow" })
      end
      publish_workflow!(post_button_workflow)

      member_guardian = Guardian.new(member)
      data =
        described_class.new(Site.new(member_guardian), scope: member_guardian, root: false).as_json

      expect(data[:post_button_workflows]).to be_empty
    end

    it "serializes position and confirmation options and honors automatic groups" do
      update_workflow_node(post_button_workflow, "trigger-1") do |node|
        node.merge(
          "parameters" => {
            "label" => "Run workflow",
            "group_ids" => [Group::AUTO_GROUPS[:logged_in_users]],
            "position" => "more_menu",
            "confirmation" => true,
            "confirmation_message" => "Really run this?",
          },
        )
      end
      publish_workflow!(post_button_workflow)

      user_guardian = Guardian.new(user)
      data = described_class.new(Site.new(user_guardian), scope: user_guardian, root: false).as_json

      expect(data[:post_button_workflows]).to contain_exactly(
        {
          trigger_node_id: "trigger-1",
          workflow_id: post_button_workflow.id,
          label: "Run workflow",
          icon: nil,
          position: "more_menu",
          confirmation: true,
          confirmation_message: "Really run this?",
        },
      )
    end
  end
end
