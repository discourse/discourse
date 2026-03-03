# frozen_string_literal: true

RSpec.describe "Chat pinned messages", type: :system do
  fab!(:admin)
  fab!(:channel, :chat_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, message: "Important message") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    SiteSetting.chat_pinned_messages = true
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

    # Another user pins the message while admin is viewing
    pin =
      Chat::PinnedMessage.create!(
        chat_message: message,
        chat_channel: channel,
        user: Fabricate(:admin),
      )
    Chat::Publisher.publish_pin!(channel, message, pin)

    expect(page).to have_css(".c-navbar__pinned-messages-btn__unread-indicator")

    find(".c-navbar__pinned-messages-btn").click
    expect(page).to have_css(".c-routes.--channel-pins")

    find(".c-navbar__close-pins-button").click

    expect(page).to have_no_css(".c-navbar__pinned-messages-btn__unread-indicator")
  end

  it "marks pins as read when viewing the panel" do
    Chat::PinnedMessage.create!(
      chat_message: message,
      chat_channel: channel,
      user: Fabricate(:admin),
    )

    chat_page.visit_channel(channel)
    expect(page).to have_css(".c-navbar__pinned-messages-btn__unread-indicator")

    find(".c-navbar__pinned-messages-btn").click
    expect(page).to have_css(".c-routes.--channel-pins")

    # Reload while panel is open — pins should stay marked as read
    page.refresh

    chat_page.visit_channel(channel)
    expect(page).to have_no_css(".c-navbar__pinned-messages-btn__unread-indicator")
  end

  it "shows unseen pin icon in the panel for pins not yet viewed" do
    other_user = Fabricate(:admin)
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: other_user)

    chat_page.visit_channel(channel)
    find(".c-navbar__pinned-messages-btn").click
    expect(page).to have_css(".c-routes.--channel-pins")
    expect(page).to have_css(".chat-pinned-message__pinned-by-icon")

    find(".c-navbar__close-pins-button").click
    find(".c-navbar__pinned-messages-btn").click
    expect(page).to have_css(".c-routes.--channel-pins")
    expect(page).to have_no_css(".chat-pinned-message__pinned-by-icon")
  end

  context "when viewing pinned messages attribution" do
    it "shows 'Pinned by you' when current user pinned the message" do
      chat_page.visit_channel(channel)
      channel_page.messages.find(id: message.id).secondary_action("pin")
      find(".c-navbar__pinned-messages-btn").click

      expect(page).to have_css(".c-routes.--channel-pins")
      expect(page).to have_css(
        ".chat-pinned-message__pinned-by",
        text: I18n.t("js.chat.pinned_messages.pinned_by_you"),
      )
    end

    context "when another user pinned the message" do
      fab!(:other_user, :user)

      before do
        channel.add(other_user)
        Chat::PinnedMessage.create!(
          chat_message: message,
          chat_channel: channel,
          pinned_by_id: other_user.id,
        )
      end

      it "shows 'Pinned by [username]'" do
        chat_page.visit_channel(channel)
        find(".c-navbar__pinned-messages-btn").click

        expect(page).to have_css(".c-routes.--channel-pins")
        expect(page).to have_css(
          ".chat-pinned-message__pinned-by",
          text: I18n.t("js.chat.pinned_messages.pinned_by_user", username: other_user.username),
        )
      end
    end
  end
end
