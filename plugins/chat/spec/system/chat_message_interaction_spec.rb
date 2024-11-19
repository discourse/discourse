# frozen_string_literal: true

RSpec.describe "Interacting with a message", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  fab!(:channel_1) { Fabricate(:chat_channel) }
  fab!(:message_1) do
    Fabricate(
      :chat_message,
      user: Discourse.system_user,
      chat_channel: channel_1,
      blocks: [
        {
          type: "actions",
          elements: [
            { value: "foo value", type: "button", text: { type: "plain_text", text: "Click Me" } },
          ],
        },
      ],
    )
  end

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:chat_channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "creates an interaction" do
    action_id = nil
    blk =
      Proc.new do |interaction|
        action_id = interaction.action["action_id"]
        Chat::CreateMessage.call(
          params: {
            message: "#{action_id}: #{interaction.action["value"]}",
            chat_channel_id: channel_1.id,
          },
          guardian: current_user.guardian,
        )
      end

    chat_page.visit_channel(channel_1)

    begin
      DiscourseEvent.on(:chat_message_interaction, &blk)
      find(".block__button").click

      try_until_success { expect(chat_channel_page.messages).to have_text(action_id) }
    ensure
      DiscourseEvent.off(:chat_message_interaction, &blk)
    end
  end
end
