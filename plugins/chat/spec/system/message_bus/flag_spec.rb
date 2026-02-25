# frozen_string_literal: true

RSpec.describe "Chat MessageBus | flag", type: :system do
  fab!(:current_user, :user)
  fab!(:staff_user, :admin)
  fab!(:channel, :category_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap(current_user, [channel])
    chat_system_user_bootstrap(user: staff_user, channel: channel)
  end

  it "staff user in second session receives the flag event" do
    sign_in(staff_user)
    chat_page.visit_channel(channel)

    using_session(:flagger) do
      sign_in(current_user)
      chat_page.visit_channel(channel)
      channel_page.messages.flag(message)
      expect(page).to have_css(".flag-modal")
      choose("radio_spam")
      click_button(I18n.t("js.chat.flagging.action"))
    end

    expect(channel_page.message_by_id(message.id)).to have_css(".chat-message-info__flag")
  end
end
