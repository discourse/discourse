# frozen_string_literal: true

describe "User preferences | Profile" do
  fab!(:user) { Fabricate(:user, active: true) }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(user) }

  describe "changing bio" do
    it "correctly updates the bio" do
      user.user_option.update!(timezone: nil)

      user_preferences_profile_page.visit(user)
      expect(user.user_option.reload.timezone).to be_present

      user_preferences_profile_page.expand_profile_details
      user_preferences_profile_page.fill_bio(with: "I am a human.")
      user_preferences_profile_page.save

      expect(user_preferences_profile_page.cooked_bio).to contain_text(
        browser_text_pattern("I am a human."),
        useInnerText: true,
      )
    end
  end

  describe "hiding profile" do
    it "allows user to hide their profile" do
      SiteSetting.allow_users_to_hide_profile = true

      user_preferences_profile_page.visit(user)
      user_preferences_profile_page.hide_profile
      user_preferences_profile_page.save
      browser_page.reload.tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(user_preferences_profile_page).to have_hidden_profile
    end
  end

  describe "enforcing required fields" do
    before do
      UserRequiredFieldsVersion.create!
      UserField.create!(
        field_type: "text",
        name: "Favourite Pokemon",
        description: "Hint: It's Mudkip.",
        requirement: :for_all_users,
        editable: true,
      )
      UserField.create!(
        field_type: "confirm",
        name: "Updated terms",
        description: "Please accept our updated our terms of service.",
        requirement: :for_all_users,
        editable: true,
      )
    end

    it "server-side redirects to the profile page to fill up required fields" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url("/u/#{user.username}/preferences/profile")

      expect(browser_root.locator(".alert-error").filter(visible: true)).to contain_text(
        [browser_text_pattern(I18n.t("js.user.preferences.profile.enforced_required_fields"))],
        useInnerText: true,
      )
    end

    it "client-side redirects to the profile page to fill up required fields" do
      browser_page.goto("/faq").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url("/guidelines")

      click_logo

      expect(browser_page).to have_url("/u/#{user.username}/preferences/profile")

      expect(browser_root.locator(".alert-error").filter(visible: true)).to contain_text(
        [browser_text_pattern(I18n.t("js.user.preferences.profile.enforced_required_fields"))],
        useInnerText: true,
      )
    end

    it "disables client-side routing while missing required fields" do
      user_preferences_profile_page.visit(user)

      click_logo

      expect(browser_page).to have_url("/u/#{user.username}/preferences/profile")
    end

    it "allows user to fill up required fields" do
      user_preferences_profile_page.visit(user)

      browser_root
        .locator(".user-field-favourite-pokemon input")
        .filter(visible: true)
        .fill("Mudkip")
      browser_root.locator(".user-field-updated-terms input").filter(visible: true).check
      browser_root.locator(".save-button .btn-primary").filter(visible: true).click

      expect(browser_root.locator(".pref-bio").filter(visible: true)).not_to have_count(0)

      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url("/")
    end

    it "does not allow submitting blank values for required fields" do
      user_preferences_profile_page.visit(user)

      browser_root.locator(".user-field-updated-terms input").filter(visible: true).check
      browser_root.locator(".save-button .btn-primary").filter(visible: true).click

      expect(dialog).to be_open
      expect(dialog).to have_displayed_content(I18n.t("login.missing_user_field"))

      dialog.click_yes

      expect(browser_root.locator(".alert-error").filter(visible: true)).to contain_text(
        [browser_text_pattern(I18n.t("js.user.preferences.profile.enforced_required_fields"))],
        useInnerText: true,
      )
    end

    it "allows enabling safe-mode" do
      browser_page.goto("/safe-mode").tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url("/safe-mode")

      browser_root.locator("#btn-enter-safe-mode").filter(visible: true).click

      expect(browser_page).to have_url("/u/#{user.username}/preferences/profile")
    end

    it "redirects back to the original destination after filling required fields" do
      category = Fabricate(:category)
      browser_page
        .goto("/new-topic?category_id=#{category.id}")
        .tap { SystemBrowserBootstrap.wait_for(browser_page) }

      expect(browser_page).to have_url("/u/#{user.username}/preferences/profile")

      browser_root
        .locator(".user-field-favourite-pokemon input")
        .filter(visible: true)
        .fill("Mudkip")
      browser_root.locator(".user-field-updated-terms input").filter(visible: true).check
      browser_root.locator(".save-button .btn-primary").filter(visible: true).click

      expect(browser_page).to have_url("/new-topic?category_id=#{category.id}")
    end
  end
end
