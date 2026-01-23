# frozen_string_literal: true

RSpec.describe "Chat pinned messages", type: :system do
  fab!(:admin)
  fab!(:channel, :chat_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, message: "Important message") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    channel.add(admin)
    sign_in(admin)
  end

  it "allows staff to pin and unpin messages" do
    chat_page.visit_channel(channel)

    channel_page.messages.find(id: message.id).secondary_action("pin")

    expect(page).to have_css(".chat-message-info__pinned")
    expect(page).to have_css(".c-navbar__pinned-messages-btn")

    find(".c-navbar__pinned-messages-btn").click
    expect(page).to have_css(".c-routes.--channel-pins")
    expect(page).to have_content("Important message")

    find(".c-navbar__close-pins-button").click
    channel_page.messages.find(id: message.id).secondary_action("unpin")

    expect(page).to have_no_css(".chat-message-info__pinned")
  end

  it "shows unread indicator for unseen pins" do
    chat_page.visit_channel(channel)

    # Pin a message
    channel_page.messages.find(id: message.id).secondary_action("pin")

    # Unread indicator should show
    expect(page).to have_css(".c-navbar__pinned-messages-btn__unread-indicator")

    # Click to view pins
    find(".c-navbar__pinned-messages-btn").click

    # Should be on pins page
    expect(page).to have_css(".c-routes.--channel-pins")

    # Go back to channel
    find(".c-navbar__close-pins-button").click

    # Indicator should be gone after viewing
    expect(page).to have_no_css(".c-navbar__pinned-messages-btn__unread-indicator")
  end
end
