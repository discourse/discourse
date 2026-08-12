# frozen_string_literal: true

RSpec.describe "Chat pinned messages" do
  fab!(:admin)
  fab!(:channel, :chat_channel)
  fab!(:message) { Fabricate(:chat_message, chat_channel: channel, message: "Important message") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  # the bar only offers the list icon (and with it the unread dot) at 2+ pins
  def pin_another_message(user: admin)
    second = Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    Chat::PinnedMessage.create!(chat_message: second, chat_channel: channel, user: user)
    second
  end

  before do
    chat_system_bootstrap
    SiteSetting.chat_pinned_messages = true
    channel.add(admin)
    sign_in(admin)
  end

  # dismissals live in local storage, which outlives a Capybara session reset,
  # and `fab!` hands every example the same channel id to key them by
  after do
    page.execute_script("window.localStorage.clear()") if page.current_url.start_with?("http")
  end

  it "allows staff to pin a message" do
    chat_page.visit_channel(channel)

    channel_page.messages.find(id: message.id).secondary_action("pin")

    expect(page).to have_css(".chat-message-info__pinned")
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Important message")
  end

  # separate example: unpinning while the bar is still appearing shifts the
  # scroller under the open message actions menu
  it "allows staff to unpin a message" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar")

    channel_page.messages.find(id: message.id).secondary_action("unpin")

    expect(page).to have_no_css(".chat-message-info__pinned")
    expect(page).to have_no_css(".chat-pinned-bar")
  end

  it "shows unread indicator for unseen pins" do
    pin_another_message # a self-pin is never unseen, and it brings out the list icon

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar")

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
    other_admin = Fabricate(:admin)
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: other_admin)
    pin_another_message(user: other_admin)

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
    pin_another_message(user: other_user)

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

    find(".chat-pinned-bar__jump").click
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Important message")

    find(".chat-pinned-bar__jump").click
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Second message")
  end

  it "shows the visited pin in the sticky bar when clicking a pin in the panel" do
    other_message = Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)
    Chat::PinnedMessage.create!(chat_message: other_message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Second message")

    find(".chat-pinned-bar__see-all").click
    find(".chat-pinned-message", text: "Important message").click

    expect(page).to have_css(".chat-pinned-bar__excerpt", text: "Important message")
  end

  it "lists pins oldest-first in the panel (channel timeline order)" do
    other_message = Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)
    Chat::PinnedMessage.create!(chat_message: other_message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    find(".chat-pinned-bar__see-all").click

    expect(page).to have_css(".chat-pinned-message:first-child", text: "Important message")
    expect(page).to have_css(".chat-pinned-message:last-child", text: "Second message")
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
    pin_another_message

    chat_page.visit_channel(channel)

    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".c-routes.--channel-pins")

    # clicking again closes the panel
    find(".chat-pinned-bar__see-all").click
    expect(page).to have_no_css(".c-routes.--channel-pins")
  end

  it "lets a user without pin permissions hide the bar from the pins panel" do
    user = Fabricate(:user)
    channel.add(user)
    other_message = Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)
    Chat::PinnedMessage.create!(chat_message: other_message, chat_channel: channel, user: admin)

    sign_in(user)
    chat_page.visit_channel(channel)
    expect(page).to have_css(".chat-pinned-bar")

    find(".chat-pinned-bar__see-all").click
    expect(page).to have_css(".chat-pinned-message", text: "Important message")
    expect(page).to have_no_css(".chat-pinned-message__unpin")

    find(".chat-pinned-messages-list__dismiss").click

    # the panel closes and the bar is dismissed (hidden) until a newer pin
    expect(page).to have_no_css(".c-routes.--channel-pins")
    expect(page).to have_no_css(".chat-pinned-bar")
  end

  it "lets a user without pin permissions dismiss a single pin from the bar and show it again" do
    user = Fabricate(:user)
    channel.add(user)
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    sign_in(user)
    chat_page.visit_channel(channel)

    find(".chat-pinned-bar__dismiss").click
    expect(page).to have_no_css(".chat-pinned-bar")

    # the navbar button reappears as the way back to the pins panel
    find(".c-navbar__pinned-messages-btn").click
    find(".chat-pinned-messages-list__show").click

    expect(page).to have_no_css(".c-routes.--channel-pins")
    expect(page).to have_css(".chat-pinned-bar")
    expect(page).to have_no_css(".c-navbar__pinned-messages-btn")
  end

  it "lets a user who can manage pins hide the bar without unpinning" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)

    chat_page.visit_channel(channel)
    find(".chat-pinned-bar__dismiss").click

    expect(page).to have_no_css(".chat-pinned-bar")
    # the message stays pinned for everyone else
    expect(channel.pinned_messages.count).to eq(1)

    find(".c-navbar__pinned-messages-btn").click
    find(".chat-pinned-messages-list__show").click

    expect(page).to have_css(".chat-pinned-bar")
    expect(page).to have_no_css(".c-navbar__pinned-messages-btn")
  end

  it "hides the bar from the pins panel for a user who can manage pins" do
    Chat::PinnedMessage.create!(chat_message: message, chat_channel: channel, user: admin)
    pin_another_message

    chat_page.visit_channel(channel)
    find(".chat-pinned-bar__see-all").click
    find(".chat-pinned-messages-list__dismiss").click

    expect(page).to have_no_css(".c-routes.--channel-pins")
    expect(page).to have_no_css(".chat-pinned-bar")
    expect(channel.pinned_messages.count).to eq(2)
  end

  context "when unpinning from the pinned messages panel" do
    fab!(:pin) do
      Fabricate(:chat_pinned_message, chat_message: message, chat_channel: channel, user: admin)
    end
    fab!(:second_message) do
      Fabricate(:chat_message, chat_channel: channel, message: "Second message")
    end
    fab!(:second_pin) do
      Fabricate(
        :chat_pinned_message,
        chat_message: second_message,
        chat_channel: channel,
        user: admin,
      )
    end

    it "lets a pin manager unpin a message from the panel" do
      chat_page.visit_channel(channel)
      find(".chat-pinned-bar__see-all").click
      expect(page).to have_css(".c-routes.--channel-pins")

      row = find(".chat-pinned-message", text: "Important message")
      row.hover
      row.find(".chat-pinned-message__unpin").click

      expect(page).to have_no_css(".chat-pinned-message", text: "Important message")
      expect(page).to have_css(".chat-pinned-message", text: "Second message")

      find(".c-navbar__close-pins-button").click

      expect(page).to have_no_css(
        ".chat-message-container[data-id='#{message.id}'] .chat-message-info__pinned",
      )
    end

    it "lets a pin manager unpin a message on mobile", mobile: true do
      chat_page.visit_channel(channel)
      find(".chat-pinned-bar__see-all").click
      expect(page).to have_css(".c-routes.--channel-pins")

      find(".chat-pinned-message", text: "Important message").find(
        ".chat-pinned-message__unpin",
      ).click

      expect(page).to have_no_css(".chat-pinned-message", text: "Important message")
    end
  end

  context "when viewing pinned messages attribution" do
    it "shows 'Pinned by you' when current user pinned the message" do
      pin_another_message

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
        pin_another_message(user: other_user)
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
