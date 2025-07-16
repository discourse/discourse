# frozen_string_literal: true

describe "Welcome banner", type: :system do
  fab!(:current_user, :user)
  let(:banner) { PageObjects::Components::WelcomeBanner.new }
  let(:search_page) { PageObjects::Pages::Search.new }

  context "when welcome banner is enabled" do
    before do
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: true)
    end

    after do
      TranslationOverride.delete_all
      I18n.reload!
    end

    it "shows for logged in and anonymous users" do
      visit "/"
      expect(banner).to be_visible
      expect(banner).to have_anonymous_title
      sign_in(current_user)
      visit "/"
      expect(banner).to have_logged_in_title(current_user.username)
    end

    context "when subheader translations are present" do
      it "shows subheader for logged in and anonymous members" do
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
    end

    context "when subheader translations are missing" do
      context "with `non-en` default locale and `en` interface locale" do
        before { SiteSetting.default_locale = "uk" }

        it "hides subheader if active locale key is missing and fallback `en` translation is an empty string" do
          TranslationOverride.upsert!(
            "uk",
            "js.welcome_banner.subheader.logged_in_members",
            "Ласкаво просимо",
          )
          sign_in(current_user)
          visit "/"
          expect(banner).to have_logged_in_subheader

          TranslationOverride.upsert!("en", "js.welcome_banner.subheader.logged_in_members", "")
          current_user.update!(locale: "en")
          sign_in(current_user)
          visit "/"
          expect(banner).to have_no_subheader
        end
      end
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
      before do
        Fabricate(
          :theme_site_setting_with_service,
          name: "search_experience",
          value: "search_field",
        )
      end

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
      before do
        Fabricate(:theme_site_setting_with_service, name: "search_experience", value: "search_icon")
      end

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
    before do
      Fabricate(:theme_site_setting_with_service, name: "enable_welcome_banner", value: false)
    end

    it "does not show the welcome banner for logged in and anonymous users" do
      visit "/"
      expect(banner).to be_hidden
      sign_in(current_user)
      visit "/"
      expect(banner).to be_hidden
    end
  end
end
