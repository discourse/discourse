# frozen_string_literal: true

RSpec.describe "Chat channel as the homepage" do
  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)
  fab!(:message_1) { Fabricate(:chat_message, chat_channel: channel_1) }

  let(:chat_page) { PageObjects::Pages::Chat.new }
  let(:channel_page) { PageObjects::Pages::ChatChannel.new }

  before do
    chat_system_bootstrap
    SiteSetting.top_menu = "latest|new|top|categories"
    SiteSetting.default_homepage = "chat"
    SiteSetting.chat_homepage_channel = channel_1.id
    sign_in(current_user)
  end

  it "renders the channel at the root path" do
    visit("/")

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path("/")
  end

  it "returns to the root path from the logo" do
    visit("/categories")
    find("#site-logo").click

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path("/")
  end

  it "keeps the channel's own path when visited directly" do
    visit(channel_1.relative_url)

    expect(channel_page.messages).to have_message(id: message_1.id)
    expect(page).to have_current_path(channel_1.relative_url)
  end

  it "shows the usual homepage when the user cannot chat" do
    SiteSetting.chat_allowed_groups = Fabricate(:group).id

    visit("/")

    # the fallback is still served at / like any other homepage
    expect(page).to have_css(".navigation-container .nav-item_latest.active")
    expect(page).to have_no_css(".chat-channel")
    expect(page).to have_current_path("/")
  end

  it "leaves an individual homepage preference alone" do
    current_user.user_option.update!(homepage_id: UserOption::HOMEPAGES.key("categories"))

    visit("/")

    expect(page).to have_css(".navigation-container .nav-item_categories.active")
    expect(page).to have_no_css(".chat-channel")
  end

  context "when the user prefers the drawer" do
    it "still opens full page from the homepage" do
      visit("/categories")
      chat_page.prefers_drawer
      find("#site-logo").click

      expect(channel_page.messages).to have_message(id: message_1.id)
      expect(page).to have_current_path("/")
    end
  end
end
