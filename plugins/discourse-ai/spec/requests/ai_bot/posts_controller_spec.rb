# frozen_string_literal: true

RSpec.describe PostsController do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:llm_model)

  before do
    enable_current_plugin
    toggle_enabled_bots(bots: [llm_model])
    SiteSetting.ai_bot_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
  end

  describe "#create" do
    it "does not send a persisted secure upload to the provider after access is revoked" do
      persona =
        Fabricate(
          :ai_persona,
          default_llm_id: llm_model.id,
          allowed_group_ids: [Group::AUTO_GROUPS[:trust_level_0]],
          allow_topic_mentions: true,
          vision_enabled: true,
        )
      persona.create_user!
      AiPersona.persona_cache.flush!

      conversation = Fabricate(:topic)
      bot_reply = Fabricate(:post, topic: conversation, user: persona.user)
      source_owner = Fabricate(:user)
      source_topic = Fabricate(:private_message_topic, user: source_owner, recipient: user)
      source_post = Fabricate(:post, topic: source_topic, user: source_owner)
      secure_upload = Fabricate(:image_upload, user: source_owner)
      secure_upload.update!(secure: true, access_control_post: source_post)

      PostCustomPrompt.create!(
        post: bot_reply,
        custom_prompt: [
          [["Look at this image", { upload_id: secure_upload.id }], user.username, "user"],
        ],
      )
      source_topic.topic_allowed_users.where(user: user).destroy_all
      Jobs.run_immediately!
      SiteSetting.ai_bot_enabled = true
      sign_in(user)

      prompts = nil
      DiscourseAi::Completions::Llm.with_prepared_responses(
        ["I can help"],
      ) do |_, _, recorded_prompts|
        post "/posts.json",
             params: {
               topic_id: conversation.id,
               raw: "Please help @#{persona.user.username}",
             }
        prompts = recorded_prompts
      end

      expect(response.status).to eq(200)
      expect(response.parsed_body["topic_id"]).to eq(conversation.id)
      expect(user.guardian.can_see_upload?(secure_upload)).to eq(false)
      expect(prompts.first.messages.flat_map { |message| Array(message[:content]) }).not_to include(
        { upload_id: secure_upload.id },
      )
    end
  end
end
