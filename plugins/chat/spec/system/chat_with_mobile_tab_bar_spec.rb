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

  it "shows the channel in the site header and leads back to the channel list and other channels" do
    chat_page.visit_channel(channel_1)

    expect(tab_bar).to have_active_tab("chat")
    expect(page).to have_css(".d-header .c-navbar__channel-title", text: channel_1.name)
    expect(page).to have_no_css(".c-navbar__back-button")
    expect(page).to have_no_css(".back-to-forum")
    expect(page).to have_no_css(".d-header .title--minimized", visible: :visible)

    tab_bar.click_tab("chat")

    expect(page).to have_no_css(".d-header .c-navbar__channel-title")
    expect(page).to have_css(".d-header .title:not(.title--minimized)")
    expect(page).to have_css(".c-footer.--pills .nav-pills #c-footer-channels.active")
    expect(page).to have_no_css(".c-footer__item")

    tab_bar.open_menu

    expect(page).to have_css(
      ".sidebar-hamburger-dropdown .sidebar-section-wrapper[data-section-name='community']",
    )
  end

  it "starts a new chat from the create button, offered first in the chat section" do
    visit("/chat")

    tab_bar.click_create

    expect(tab_bar).to have_create_actions("New chat", "New topic", "New personal message")

    tab_bar.click_create_action("New chat")

    expect(page).to have_css(".chat-modal-new-message")
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

  it "keeps chat search in the site header rather than among the chat tabs" do
    SiteSetting.chat_search_enabled = true

    visit("/chat")

    expect(page).to have_css(".c-footer.--pills")
    expect(page).to have_no_css("#c-footer-search")

    find(".d-header .c-header__search a").click

    expect(page).to have_current_path("/chat/search")
    expect(page).to have_css(".d-header .c-header__search .active")
  end

  it "lets the chat tabs name the list and holds its options beside them" do
    visit("/chat")

    expect(page).to have_css(
      ".c-footer.--pills .c-footer__options .chat-channel-list-options-button",
    )
    expect(page).to have_no_css(".c-routes.--channels > .c-navbar-container")
  end
end
