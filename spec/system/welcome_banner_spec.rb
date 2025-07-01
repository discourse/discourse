# frozen_string_literal: true

describe "Welcome banner", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  let(:banner) { PageObjects::Components::WelcomeBanner.new }
  let(:search_page) { PageObjects::Pages::Search.new }

  context "when welcome banner is enabled" do
    before { SiteSetting.enable_welcome_banner = true }

    it "shows for logged in and anonymous users" do
      visit "/"
      expect(banner).to be_visible
      expect(banner).to have_anonymous_title
      sign_in(current_user)
      visit "/"
      expect(banner).to have_logged_in_title(current_user.username)
    end

    it "shows subheader when translations are present for logged in and anonymous members" do
      visit "/"
      expect(banner).to be_visible
      expect(banner).to have_no_subheader
      TranslationOverride.upsert!(
        "en",
        "js.welcome_banner.subheader.anonymous_members",
        "Something about us.",
      )
      visit "/"
      expect(banner).to have_anonymous_subheader

      TranslationOverride.upsert!(
        "en",
        "js.welcome_banner.subheader.logged_in_members",
        "We are so cool!",
      )
      sign_in(current_user)
      visit "/"
      expect(banner).to have_logged_in_subheader
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

    context "when using search_field search_experience" do
      before { SiteSetting.search_experience = "search_field" }

      it "hides welcome banner and shows header search on scroll, and vice-versa" do
        Fabricate(:topic)

        sign_in(current_user)
        visit "/"
        expect(banner).to be_visible
        expect(search_page).to have_no_search_field

        fake_scroll_down_long

        expect(banner).to be_invisible
        expect(search_page).to have_search_field

        page.scroll_to(0, 0)
        expect(banner).to be_visible
        expect(search_page).to have_no_search_field
      end
    end

    context "when using search_icon search_experience" do
      before { SiteSetting.search_experience = "search_icon" }

      it "hides welcome banner and shows header search on scroll, and vice-versa" do
        Fabricate(:topic)

        sign_in(current_user)
        visit "/"
        expect(banner).to be_visible
        expect(search_page).to have_no_search_icon

        fake_scroll_down_long

        expect(banner).to be_invisible
        expect(search_page).to have_search_icon

        page.scroll_to(0, 0)
        expect(banner).to be_visible
        expect(search_page).to have_no_search_icon
      end
    end
  end

  context "when welcome banner is not enabled" do
    before { SiteSetting.enable_welcome_banner = false }

    it "does not show the welcome banner for logged in and anonymous users" do
      visit "/"
      expect(banner).to be_hidden
      sign_in(current_user)
      visit "/"
      expect(banner).to be_hidden
    end
  end
end
