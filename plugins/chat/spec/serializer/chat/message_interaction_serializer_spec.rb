# frozen_string_literal: true
RSpec.describe Chat::MessageInteractionSerializer do
  subject(:serializer) do
    interaction =
      Fabricate(
        :chat_message_interaction,
        message:,
        user:,
        action: message.blocks.first["elements"].first,
      )
    described_class.new(interaction, scope: Guardian.new(user), root: false)
  end

  fab!(:user)

  let(:message) do
    Fabricate(
      :chat_message,
      chat_channel: channel,
      user: Discourse.system_user,
      blocks: [
        {
          type: "actions",
          elements: [
            { type: "button", text: { type: "plain_text", text: "Like" }, action_id: "like" },
          ],
        },
      ],
    )
  end
  let(:message_id) { message.id }
  let(:params) { { message_id:, action_id: "like" } }

  before do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:everyone]
    SiteSetting.direct_message_enabled_groups = Group::AUTO_GROUPS[:everyone]
  end

  context "when interaction's channel is private" do
    let(:channel) { Fabricate(:direct_message_channel, users: [user, Fabricate(:user)]) }

    it "serializes the interaction" do
      expect(serializer.as_json).to match_response_schema("message_interaction")
    end
  end

  context "when interaction's channel is public" do
    let(:channel) { Fabricate(:chat_channel) }

    it "serializes the interaction" do
      expect(serializer.as_json).to match_response_schema("message_interaction")
    end
  end
end
