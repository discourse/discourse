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

      avatar_selector_modal.select_avatar_upload_option
      file_path = File.absolute_path(file_from_fixtures("logo.jpg"))
      attach_file(file_path) { avatar_selector_modal.click_avatar_upload_button }
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
