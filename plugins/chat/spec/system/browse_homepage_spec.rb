# frozen_string_literal: true

RSpec.describe "Chat channel directory as the homepage" do
  fab!(:current_user, :user)
  fab!(:channel_1, :category_channel)

  let(:browse_page) { PageObjects::Pages::ChatBrowse.new }

  before do
    chat_system_bootstrap
    SiteSetting.top_menu = "latest|new|top|categories"
    SiteSetting.default_homepage = "chat_browse"
  end

  context "when signed in" do
    before { sign_in(current_user) }

    it "renders open channels at the root path" do
      visit("/")

      expect(browse_page).to have_channel(name: channel_1.name)
      expect(page).to have_current_path("/")
    end

    it "returns to the root path from the logo" do
      visit("/categories")
      find("#site-logo").click

      expect(browse_page).to have_channel(name: channel_1.name)
      expect(page).to have_current_path("/")
    end

    it "shows the usual homepage when the user cannot chat" do
      SiteSetting.chat_allowed_groups = Fabricate(:group).id

      visit("/")

      expect(page).to have_css(".navigation-container .nav-item_latest.active")
      expect(page).to have_no_css(".chat-browse-view")
      expect(page).to have_current_path("/")
    end
  end

  it "shows anonymous visitors the usual homepage" do
    SiteSetting.chat_allowed_groups = Group::AUTO_GROUPS[:anonymous_users]

    visit("/")

    expect(page).to have_css(".navigation-container .nav-item_latest.active")
    expect(page).to have_no_css(".chat-browse-view")
    expect(page).to have_current_path("/")
  end
end
