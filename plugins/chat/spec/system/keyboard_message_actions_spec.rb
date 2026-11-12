# frozen_string_literal: true

RSpec.describe "Chat | keyboard access to message actions" do
  fab!(:current_user, :user)
  fab!(:channel_1, :chat_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }
  fab!(:message_2) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }
  let(:drawer_page) { PageObjects::Pages::ChatDrawer.new }

  before do
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  def focused
    page.evaluate_script(<<~JS)
      (() => {
        const active = document.activeElement;
        if (!active) {
          return {};
        }
        const message = active.closest(".chat-message-container");
        return {
          messageId: message && message.dataset.id,
          inActions: !!active.closest(".chat-message-actions"),
        };
      })()
    JS
  end

  # sibling reaction buttons are indistinguishable by class, so position is what tells us
  # focus actually moved
  def focused_position
    page.evaluate_script(<<~JS)
      Array.from(
        document.querySelectorAll(".chat-message-actions > *")
      ).findIndex(
        (item) => item === document.activeElement || item.contains(document.activeElement)
      )
    JS
  end

  def focus_author(message)
    page.execute_script(<<~JS)
      document
        .querySelector(".chat-message-container[data-id='#{message.id}'] .chat-message-info__username__name")
        .focus()
    JS
  end

  it "reaches a message's actions by tabbing on from the message" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_1.id)).to be_present

    focus_author(message_1)

    # focus raises the actions the pointer gets by hovering, and they render inside the
    # message, so tabbing on walks into them rather than skipping to the next message
    expect(page).to have_css(
      ".chat-message-container[data-id='#{message_1.id}'] .chat-message-actions",
    )

    reached = false
    6.times do
      page.send_keys(:tab)
      current = focused
      expect(current["messageId"]).to eq(message_1.id.to_s)

      if current["inActions"]
        reached = true
        break
      end
    end

    expect(reached).to eq(true)
  end

  it "keeps a single set of actions on the page" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_2.id)).to be_present

    focus_author(message_1)
    expect(page).to have_css(".chat-message-actions", count: 1)

    focus_author(message_2)
    expect(page).to have_css(
      ".chat-message-container[data-id='#{message_2.id}'] .chat-message-actions",
    )
    expect(page).to have_css(".chat-message-actions", count: 1)
  end

  it "names every action, since they are all icon-only" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_1.id)).to be_present

    focus_author(message_1)
    expect(page).to have_css(".chat-message-actions")

    expect(page).to have_css(
      ".chat-message-actions[role='toolbar'][aria-label='#{I18n.t("js.chat.message_actions")}']",
    )
    expect(page).to have_css(".chat-message-actions .react-btn[title='#{I18n.t("js.chat.react")}']")
    expect(page).to have_css(".chat-message-actions .reply-btn[title='#{I18n.t("js.chat.reply")}']")
    expect(page).to have_css(
      ".chat-message-actions .bookmark-btn[aria-label='#{I18n.t("js.chat.bookmark_message")}']",
    )
    expect(page).to have_css(
      ".more-buttons [aria-label='#{I18n.t("js.chat.more_message_actions")}']",
    )
  end

  it "announces the author once, and lets a keyboard reach them" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_1.id)).to be_present

    # the avatar link's own name is the username it sits beside, so it would be announced
    # twice and cost a tab stop reaching the same place
    expect(page).to have_css(
      ".chat-message-container[data-id='#{message_1.id}'] .chat-user-avatar__container[aria-hidden='true'][tabindex='-1']",
    )
    expect(page).to have_css(
      ".chat-message-container[data-id='#{message_1.id}'] button.chat-message-info__username__name",
    )

    # the message itself is not a control, so it is not announced as one and does not
    # read out its actions as part of its own text
    expect(page).to have_no_css(".chat-message-container[tabindex]")
  end

  it "costs one tab stop, with arrows moving along it" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_1.id)).to be_present

    focus_author(message_1)
    expect(page).to have_css(".chat-message-actions")

    # a toolbar is a single stop, not one per button
    expect(page).to have_css(".chat-message-actions [tabindex='0']", count: 1)

    tabbable =
      page.evaluate_script(
        "document.querySelectorAll(\".chat-message-actions [tabindex='0'], .chat-message-actions [tabindex]:not([tabindex='-1'])\").length",
      )
    expect(tabbable).to eq(1)

    page.execute_script("document.querySelector(\".chat-message-actions [tabindex='0']\").focus()")
    expect(focused_position).to eq(0)

    page.send_keys(:right)
    expect(focused_position).to eq(1)
    expect(focused["inActions"]).to eq(true)

    page.send_keys(:left)
    expect(focused_position).to eq(0)
  end

  it "keeps its tab stop in a pane too narrow for the favourite reactions" do
    chat_page.prefers_drawer
    visit("/")
    chat_page.open_from_header
    drawer_page.open_channel(channel_1)
    expect(page).to have_css(".chat-drawer .chat-message-container[data-id='#{message_1.id}']")

    page.execute_script(<<~JS)
      document
        .querySelector(".chat-drawer .chat-message-container[data-id='#{message_1.id}'] .chat-message-info__username__name")
        .focus()
    JS

    expect(page).to have_css(".chat-message-actions-container.is-size-reduced")

    # the reduced pane drops the favourite reactions, which is where the tab stop starts
    expect(page).to have_css(".chat-message-actions [tabindex='0']", count: 1)
  end

  it "drops the actions once focus leaves the message" do
    chat_page.visit_channel(channel_1)
    expect(channel_page.message_by_id(message_1.id)).to be_present

    focus_author(message_1)
    expect(page).to have_css(".chat-message-actions")

    page.execute_script("document.querySelector('.chat-composer__input').focus()")
    expect(page).to have_no_css(".chat-message-actions")
  end
end
