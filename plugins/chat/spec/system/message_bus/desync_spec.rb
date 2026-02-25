# frozen_string_literal: true

RSpec.describe "Chat MessageBus | desync", type: :system do
  fab!(:current_user, :user)
  fab!(:other_user, :user)
  fab!(:channel, :chat_channel)

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    SiteSetting.navigation_menu = "sidebar"
    chat_system_bootstrap(current_user, [channel])
    channel.add(other_user)
  end

  it "reloads when the client detects a message bus gap" do
    sign_in(current_user)
    chat_page.visit_channel(channel)

    page.execute_script("document.body.dataset.desyncMarker = '1'")

    # Simulate stalled client
    page.execute_script(<<~JS)
      window.Discourse.lookup("service:chat-channels-manager")
        .channels.find(c => c.id === #{channel.id})
        .channelMessageBusLastId = 99999;
    JS

    Fabricate(:chat_message, chat_channel: channel, user: other_user, use_service: true)

    expect(channel_page.messages).to have_message(id: channel.chat_messages.last.id)

    # Simulate the user returning to the tab
    page.execute_script(<<~JS)
      window.Discourse.lookup("service:chat").onPresenceChangeCallback(true);
    JS

    expect(page).to have_no_css("[data-desync-marker]")
    chat_page.has_finished_loading?
  end
end
