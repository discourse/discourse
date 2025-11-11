# frozen_string_literal: true

describe "User preferences | Account", type: :system do
  fab!(:user) { Fabricate(:user, refresh_auto_groups: true) }
  let(:user_account_preferences_page) { PageObjects::Pages::UserPreferencesAccount.new }
  let(:avatar_selector_modal) { PageObjects::Modals::AvatarSelector.new }

  before { sign_in(user) }

  describe "avatar-selector modal" do
    it "saves custom picture and system assigned pictures" do
      user_account_preferences_page.open_avatar_selector_modal(user)
      expect(avatar_selector_modal).to be_open
      expect(avatar_selector_modal).to have_avatar_options("system", "gravatar", "upload")

      avatar_selector_modal.select_avatar_upload_option
      file_path = File.absolute_path(file_from_fixtures("logo.jpg"))
      attach_file("custom-profile-upload", file_path, make_visible: true)
      expect(avatar_selector_modal).to have_user_avatar_image_uploaded
      avatar_selector_modal.click_primary_button
      expect(avatar_selector_modal).to be_closed
      expect(user_account_preferences_page).to have_custom_uploaded_avatar_image

      user_account_preferences_page.open_avatar_selector_modal(user)
      avatar_selector_modal.select_system_assigned_option
      avatar_selector_modal.click_primary_button
      expect(avatar_selector_modal).to be_closed
      expect(user_account_preferences_page).to have_system_avatar_image
    end

    it "does not allow for custom pictures when the user is not in uploaded_avatars_allowed_groups" do
      SiteSetting.uploaded_avatars_allowed_groups = Group::AUTO_GROUPS[:admins]
      user_account_preferences_page.open_avatar_selector_modal(user)
      expect(avatar_selector_modal).to be_open
      expect(avatar_selector_modal).to have_no_avatar_upload_button
    end

    it "does not show Gravatar option when gravatars are not enabled" do
      SiteSetting.gravatar_enabled = false

      user_account_preferences_page.open_avatar_selector_modal(user)
      expect(avatar_selector_modal).to be_open
      expect(avatar_selector_modal).to have_avatar_options("system", "upload")
    end
  end

  describe "overridden provider attributes" do
    before do
      authenticator =
        Class
          .new(Auth::ManagedAuthenticator) do
            def name
              "test_auth"
            end

            def enabled?
              true
            end
          end
          .new

      provider =
        Auth::AuthProvider.new(
          authenticator:,
          icon: "flash",
          icon_setting: :test_icon,
          pretty_name: "old pretty name",
          pretty_name_setting: :test_pretty_name,
          title: "old_title",
          title_setting: :test_title,
        )
      DiscoursePluginRegistry.register_auth_provider(provider)

      allow(SiteSetting).to receive(:get).and_call_original
      allow(SiteSetting).to receive(:get).with(:test_icon).and_return("bullseye")
      allow(SiteSetting).to receive(:get).with(:test_pretty_name).and_return("new pretty name")
      allow(SiteSetting).to receive(:get).with(:test_title).and_return("new_title")
    end

    after { DiscoursePluginRegistry.reset! }

    it "displays the correct name when overridden" do
      user_account_preferences_page.visit(user)
      name = find(".pref-associated-accounts table tr.test-auth .associated-account__name")
      expect(name).not_to have_text("old pretty name")
      expect(name).to have_text("new pretty name")
    end

    it "displays the correct icon when overridden" do
      user_account_preferences_page.visit(user)
      icon_classes =
        find(".pref-associated-accounts table tr.test-auth .associated-account__icon svg")[:class]
      expect(icon_classes).not_to have_content("d-icon-flash")
      expect(icon_classes).to have_content("d-icon-bullseye")
    end
  end

  describe "external login provider URLs" do
    it "shows provider URLs as links when available" do
      SiteSetting.enable_discord_logins = true
      SiteSetting.enable_facebook_logins = true
      SiteSetting.enable_github_logins = true
      SiteSetting.enable_google_oauth2_logins = true

      # Let's connect at least 1 external account
      UserAssociatedAccount.create!(
        user:,
        provider_name: "google_oauth2",
        provider_uid: "123456",
        info: {
          "email" => user.email,
        },
      )

      user_account_preferences_page.visit(user)

      name = find(".pref-associated-accounts table tr.discord .associated-account__name")
      expect(name).to have_link("Discord", href: "https://discord.com")

      name = find(".pref-associated-accounts table tr.facebook .associated-account__name")
      expect(name).to have_link("Facebook", href: "https://www.facebook.com")

      name = find(".pref-associated-accounts table tr.github .associated-account__name")
      expect(name).to have_link("GitHub", href: "https://github.com")

      name = find(".pref-associated-accounts table tr.google-oauth2 .associated-account__name")
      expect(name).to have_link("Google", href: "https://accounts.google.com")
    end

    it "shows provider names without links when provider_url is not implemented" do
      begin
        authenticator =
          Class
            .new(Auth::ManagedAuthenticator) do
              def name
                "test_no_url"
              end

              def enabled?
                true
              end
            end
            .new

        provider = Auth::AuthProvider.new(authenticator:, icon: "flash")
        DiscoursePluginRegistry.register_auth_provider(provider)

        user_account_preferences_page.visit(user)

        name = find(".pref-associated-accounts table tr.test-no-url .associated-account__name")
        expect(name).not_to have_css("a")
      ensure
        DiscoursePluginRegistry.reset!
      end
    end
  end
end
