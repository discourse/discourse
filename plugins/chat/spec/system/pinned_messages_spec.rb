# frozen_string_literal: true

RSpec.describe "Chat pinned messages" do
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
    expect(page).to have_css(".chat-pinned-bar__see-all")

    find(".chat-pinned-bar__see-all").click
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

    expect(page).to have_css(".chat-pinned-bar__unread-indicator")

    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")

    find(".c-navbar__close-pins-button").click

    expect(page).to have_no_css(".chat-pinned-bar__unread-indicator")
  end

  it "marks pins as read when viewing the panel" do
    Chat::PinnedMessage.create!(
      chat_message: message,
      chat_channel: channel,
      user: Fabricate(:admin),
    )

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar__unread-indicator")

    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")

    # Reload while panel is open — pins should stay marked as read
    page.refresh

    chat_page.visit_channel(channel)
    expect(page).to have_no_css(".chat-pinned-bar__unread-indicator")
  end

  it "shows unseen pin icon in the panel for pins not yet viewed" do
    other_user = Fabricate(:admin)
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: other_user)

    chat_page.visit_channel(channel)
    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")
    expect(page).to have_css(".chat-pinned-message__pinned-by-icon")

    find(".c-navbar__close-pins-button").click
    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")
    expect(page).to have_no_css(".chat-pinned-message__pinned-by-icon")
  end

  it "keeps the sticky bar in sync as messages are pinned and unpinned" do
    other_message = Fabricate(:chat_message, chat_channel: channel, message: "Second message")

    chat_page.visit_channel(channel)

    # first pin: bar appears, no position indicator for a single pin
    channel_page.messages.find(id: message.id).secondary_action("pin")
    expect(page).to have_css(".chat-pinned-bar")
    expect(page).to have_no_css(".chat-pinned-bar__indicator")

    # second pin: position indicator appears with a segment per pin
    channel_page.messages.find(id: other_message.id).secondary_action("pin")
    expect(page).to have_css(".chat-pinned-bar__indicator-segment", count: 2)

    # unpin one: bar stays, back to a single pin
    channel_page.messages.find(id: other_message.id).secondary_action("unpin")
    expect(page).to have_css(".chat-pinned-bar")
    expect(page).to have_no_css(".chat-pinned-bar__indicator")

    # unpin the last one: bar disappears
    channel_page.messages.find(id: message.id).secondary_action("unpin")
    expect(page).to have_no_css(".chat-pinned-bar")
  end

  it "cycles through pins when clicking the sticky bar" do
    other_message = Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)
    Chat::PinnedMessage.create!(chat_message: other_message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)

    # newest pin is shown first
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Second message")

    find(".chat-pinned-bar__main").click
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Important message")

    find(".chat-pinned-bar__main").click
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Second message")
  end

  it "removes a pinned message from the bar when it is deleted" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar")

    # deleting unpins server-side and broadcasts an unpin event
    channel_page.messages.delete(message)

    expect(page).to have_no_css(".chat-pinned-bar")
  end

  it "toggles the pinned messages panel from the bar's see-all button" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)

    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")

    # clicking again closes the panel
    find(".chat-pinned-bar__see-all").click
    expect(page).to have_no_css(".c-routes.--channel-pins")
  end

  it "lets a user hide the bar from the pins panel" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar")

    find(".chat-pinned-bar__see-all").click
    find(".chat-pinned-messages-list__dismiss").click

    # the panel closes and the bar is dismissed (hidden) until a newer pin
    expect(page).to have_no_css(".c-routes.--channel-pins")
    expect(page).to have_no_css(".chat-pinned-bar")
  end

  context "when viewing pinned messages attribution" do
    it "shows 'Pinned by you' when current user pinned the message" do
      chat_page.visit_channel(channel)
      channel_page.messages.find(id: message.id).secondary_action("pin")

      expect(page).to have_css(".chat-message-info__pinned")
      find(".chat-pinned-bar__see-all").click

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
        find(".chat-pinned-bar__see-all").click

        expect(page).to have_css(".c-routes.--channel-pins")
        expect(page).to have_css(
          ".chat-pinned-message__pinned-by",
          text: I18n.t("js.chat.pinned_messages.pinned_by_user", username: other_user.username),
        )
      end
    end
  end
end
