# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::NodeTypesController do
  fab!(:admin)

  before do
    SiteSetting.discourse_workflows_enabled = true

    DiscourseWorkflows::Registry.reset!
    DiscourseWorkflows::Registry.register_trigger(DiscourseWorkflows::Triggers::TopicClosed::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::AppendTags::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreatePost::V1)
    DiscourseWorkflows::Registry.register_action(DiscourseWorkflows::Actions::CreateTopic::V1)
    DiscourseWorkflows::Registry.register_condition(DiscourseWorkflows::Conditions::IfCondition::V1)

    sign_in(admin)
  end

  after { DiscourseWorkflows::Registry.reset! }

  describe "GET /admin/plugins/discourse-workflows/node-types" do
    it "returns all registered node types" do
      get "/admin/plugins/discourse-workflows/node-types.json"

      expect(response.status).to eq(200)
      json = response.parsed_body
      identifiers = json["node_types"].map { |nt| nt["identifier"] }

      expect(identifiers).to include("trigger:topic_closed")
      expect(identifiers).to include("action:append_tags")
      expect(identifiers).to include("action:create_post")
      expect(identifiers).to include("action:create_topic")
      expect(identifiers).to include("condition:if")
    end
  end
end
