# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::Executor do
  fab!(:admin)
  fab!(:topic_owner) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:first_post) { create_post(user: topic_owner, raw: "First post") }
  fab!(:topic) { first_post.topic }

  before { SiteSetting.discourse_workflows_enabled = true }

  describe "#run" do
    it "creates a post from trigger data" do
      graph =
        build_workflow_graph do |g|
          g.node "trigger-1", "trigger:manual"
          g.node "action-1",
                 "action:create_post",
                 name: "Create Post",
                 configuration: {
                   "topic_id" => "={{ trigger.topic_id }}",
                   "raw" => "={{ trigger.raw }}",
                   "reply_to_post_number" => "={{ trigger.reply_to_post_number }}",
                   "user_id" => "={{ trigger.user_id }}",
                 }
          g.chain "trigger-1", "action-1"
        end
      workflow = Fabricate(:discourse_workflows_workflow, created_by: admin, enabled: true, **graph)

      trigger_data = {
        topic_id: topic.id,
        raw: "Generated reply",
        reply_to_post_number: first_post.post_number,
        user_id: admin.id,
      }

      execution = described_class.new(workflow, "trigger-1", trigger_data).run
      reply = topic.posts.order(:id).last

      expect(execution.status).to eq("success")
      expect(reply.raw).to eq("Generated reply")
      expect(reply.reply_to_post_number).to eq(first_post.post_number)
      expect(reply.user_id).to eq(admin.id)
      expect(execution.execution_data.context_data["Create Post"].first["json"]["post"]).to include(
        "id" => reply.id,
        "raw" => "Generated reply",
        "user_id" => admin.id,
        "post_number" => reply.post_number,
      )
    end
  end
end
