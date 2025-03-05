# frozen_string_literal: true

describe "Welcome banner", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  let(:banner) { PageObjects::Components::WelcomeBanner.new }

  context "when welcome banner is enabled" do
    before { SiteSetting.show_welcome_banner = true }

    it "shows for logged in and anonymous users" do
      visit "/"
      expect(banner).to be_visible
      expect(banner).to have_anonymous_title
      sign_in(current_user)
      visit "/"
      expect(banner).to have_logged_in_title(current_user.username)
    end

    it "only displays on top_menu routes" do
      sign_in(current_user)
      SiteSetting.remove_override!(:top_menu)
      topic = Fabricate(:topic)
      visit "/"
      expect(banner).to be_visible
      visit "/latest"
      expect(banner).to be_visible
      visit "/new"
      expect(banner).to be_visible
      visit "/unread"
      expect(banner).to be_visible
      visit "/hot"
      expect(banner).to be_visible
      visit "/tags"
      expect(banner).to be_hidden
      visit topic.relative_url
      expect(banner).to be_hidden
    end

    xit "hides welcome banner and shows header search on scroll, and vice-versa" do
    end
  end

  context "when welcome banner is not enabled" do
    before { SiteSetting.show_welcome_banner = false }

    it "does not show the welcome banner" do
      visit "/"
      expect(banner).to be_hidden
    end
  end
end
