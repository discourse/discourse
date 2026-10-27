# frozen_string_literal: true

RSpec.describe "Chat with mobile tab bar", mobile: true do
  fab!(:current_user, :user)
  fab!(:channel_1) { Fabricate(:category_channel, name: "Kittens") }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:tab_bar) { PageObjects::Components::MobileTabBar.new }

  before do
    SiteSetting.enable_mobile_tab_bar = true
    chat_system_bootstrap
    channel_1.add(current_user)
    sign_in(current_user)
  end

  it "shows the channel in the site header and opens the chat menu from its tab" do
    chat_page.visit_channel(channel_1)

    expect(tab_bar).to have_active_tab("chat")
    expect(page).to have_css(".d-header .c-navbar__channel-title", text: channel_1.name)
    expect(page).to have_no_css(".c-navbar__back-button")
    expect(page).to have_no_css(".back-to-forum")
    expect(page).to have_no_css(".d-header .title--minimized", visible: :visible)

    tab_bar.click_tab("chat")

    expect(page).to have_css(
      ".sidebar-hamburger-dropdown .chat-panel .sidebar-section-link",
      text: channel_1.name,
    )
    expect(page).to have_css(".sidebar-menu-action__button", text: "New message")

    tab_bar.click_tab("chat")

    expect(page).to have_no_css(".sidebar-hamburger-dropdown")
  end

  it "shows the user their unread direct messages on the chat tab" do
    other_user = Fabricate(:user)
    dm_channel = Fabricate(:direct_message_channel, users: [current_user, other_user])
    Fabricate(:chat_message_with_service, chat_channel: dm_channel, user: other_user)

    visit("/latest")

    expect(page).to have_css(
      ".mobile-tab-bar__tab[data-key='chat'] .mobile-tab-bar__badge .chat-channel-unread-indicator",
    )
  end
end
