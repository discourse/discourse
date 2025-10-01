# frozen_string_literal: true

describe "Welcome banner", type: :system do
  fab!(:current_user, :user)
  let(:banner) { PageObjects::Components::WelcomeBanner.new }
  let(:search_page) { PageObjects::Pages::Search.new }

  context "when enabled" do
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

    context "with subheader translations" do
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

    context "with empty subheader translations (default)" do
      context "with `non-en` default locale and `en` interface locale" do
        before do
          SiteSetting.default_locale = "uk"
          SiteSetting.allow_user_locale = true
        end

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

    context "for background image setting" do
      fab!(:current_user, :admin)
      fab!(:bg_img) { Fabricate(:image_upload, color: "cyan") }

      before { SiteSetting.welcome_banner_page_visibility = "all_pages" }

      it "shows banner without background image" do
        sign_in(current_user)
        visit "/"
        expect(banner).to be_visible
        expect(banner).to have_no_bg_img
      end

      it "sets a background image with uploaded image" do
        SiteSetting.welcome_banner_image = bg_img

        sign_in(current_user)
        visit "/"
        expect(banner).to have_bg_img(bg_img.url)
      end

      context "for text color setting" do
        let(:red) { "#ff0000" }
        before { SiteSetting.welcome_banner_text_color = red }

        it "doesn't set text color without background image" do
          visit "/"
          expect(banner).to have_no_custom_text_color(red)
        end

        it "applies text color if background image is set" do
          SiteSetting.welcome_banner_image = bg_img
          visit "/"
          expect(banner).to have_custom_text_color(red)
        end
      end
    end

    context "with interface location setting" do
      it "shows above topic content" do
        SiteSetting.welcome_banner_location = "above_topic_content"
        visit "/"
        expect(banner).to be_above_topic_content
      end

      it "shows below site header" do
        SiteSetting.welcome_banner_location = "below_site_header"
        visit "/"
        expect(banner).to be_below_site_header
      end
    end

    context "with interface page visibility setting" do
      before { current_user.update!(admin: true) }

      context "when show on all pages" do
        fab!(:invite)
        let(:inactive_user_email_token) do
          Fabricate(:email_token, user: Fabricate(:user, active: false))
        end
        let(:password_reset_email_token) do
          current_user.email_tokens.create!(
            email: current_user.email,
            scope: EmailToken.scopes[:password_reset],
          )
        end

        before { SiteSetting.welcome_banner_page_visibility = "all_pages" }

        it "should show on" do
          sign_in(current_user)

          visit "/"
          expect(banner).to be_visible

          visit "/u/#{current_user.username}/preferences/emails"
          expect(banner).to be_visible

          visit "/my/messages"
          expect(banner).to be_visible
        end

        it "should NOT show on" do
          visit "/login"
          expect(banner).to be_hidden

          visit "/signup"
          expect(banner).to be_hidden

          visit "/invites/#{invite.invite_key}"
          expect(banner).to be_hidden

          visit "/u/activate-account/#{inactive_user_email_token}"
          expect(banner).to be_hidden

          sign_in(current_user)
          visit "/u/password-reset/#{password_reset_email_token}"
          expect(banner).to be_hidden

          visit "/admin"
          expect(banner).to be_hidden

          visit "/admin/config/site-admin"
          expect(banner).to be_hidden

          visit "/admin/customize"
          expect(banner).to be_hidden
        end
      end

      it "should show on discovery routes only" do
        sign_in(current_user)
        SiteSetting.welcome_banner_page_visibility = "discovery"

        visit "/filter?q=tag%3Ain-progress"
        expect(banner).to be_visible

        visit "/upcoming-events?view=month"
        expect(banner).to be_hidden
      end

      it "should show on top menu pages only" do
        sign_in(current_user)
        SiteSetting.welcome_banner_page_visibility = "top_menu_pages"
        SiteSetting
          .top_menu
          .split("|")
          .each do |route|
            visit "/#{route}"
            expect(banner).to be_visible
          end

        visit "/my/posts"
        expect(banner).to be_hidden
      end

      it "should show on homepage only" do
        SiteSetting.welcome_banner_page_visibility = "homepage"

        visit "/"
        expect(banner).to be_visible

        sign_in(current_user)
        visit "/new"
        expect(banner).to be_hidden
      end
    end
  end

  context "when disabled" do
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
