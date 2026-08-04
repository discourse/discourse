# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:admin) { Fabricate(:admin, refresh_auto_groups: true) }
  fab!(:llm_model)

  let(:bot_user) { llm_model.reload.user }

  fab!(:restricted_agent) do
    Fabricate(
      :ai_agent,
      allowed_group_ids: [Group::AUTO_GROUPS[:admins]],
      allow_personal_messages: true,
    )
  end

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    SiteSetting.min_personal_message_post_length = 5
  end

  describe "#create" do
    it "uses the topic creator permissions for stored agent ids" do
      sign_in(user)

      post "/posts.json",
           params: {
             archetype: Archetype.private_message,
             raw: "Can you help me with this?",
             target_recipients: "#{admin.username},#{bot_user.username}",
             title: "AI agent escalation attempt",
             topic_custom_fields: {
               ai_agent_id: restricted_agent.id,
             },
           }

      topic_id = response.parsed_body["topic_id"]

      aggregate_failures do
        expect(response.status).to eq(200)
        expect(topic_id).to be_present
      end

      sign_in(admin)

      expect_not_enqueued_with(job: :create_ai_reply, args: { agent_id: restricted_agent.id }) do
        post "/posts.json", params: { raw: "I'll look into this.", topic_id: topic_id }
      end

      aggregate_failures do
        expect(response.status).to eq(200)
        expect(response.parsed_body["topic_id"]).to eq(topic_id)
      end
    end
  end
end
