# frozen_string_literal: true

describe "AI Chat model labels" do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  fab!(:agent) { Fabricate(:ai_agent).tap(&:ensure_user!) }
  fab!(:channel) { Fabricate(:direct_message_channel, users: [user, agent.user]) }

  let(:chat) { PageObjects::Pages::Chat.new }
  let(:chat_channel) { PageObjects::Pages::ChatChannel.new }
  let(:ai_message) { PageObjects::Components::AiChatMessage.new }

  before do
    enable_current_plugin
    SiteSetting.chat_enabled = true
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:trust_level_0].to_s
    sign_in(user)
    chat.prefers_full_page
  end

  it "shows the model for an existing reply" do
    message = Fabricate(:chat_message, chat_channel: channel, user: agent.user)
    message.custom_fields[DiscourseAi::AiBot::CHAT_MESSAGE_AI_LLM_NAME_FIELD] = "Model 猫"
    message.save_custom_fields

    chat.visit_channel(channel)
    expect(ai_message).to have_model(message, "Model 猫")
  end

  it "shows the model when a streamed reply finishes without changing its text" do
    message = Fabricate(:chat_message, chat_channel: channel, user: agent.user, streaming: true)
    chat.visit_channel(channel)
    expect(chat_channel.messages).to have_message(id: message.id)
    expect(ai_message).to have_no_model(message)

    message.custom_fields[DiscourseAi::AiBot::CHAT_MESSAGE_AI_LLM_NAME_FIELD] = "Model 猫"
    message.save_custom_fields
    ChatSDK::Message.stop_stream(message_id: message.id, guardian: Guardian.new(agent.user))

    expect(ai_message).to have_model(message, "Model 猫")
  end
end
