# frozen_string_literal: true

describe "User preferences | Profile", type: :system do
  fab!(:user) { Fabricate(:user, active: true) }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }
  let(:dialog) { PageObjects::Components::Dialog.new }

  before { sign_in(user) }

  describe "changing bio" do
    it "correctly updates the bio" do
      user_preferences_profile_page.visit(user)

      user_preferences_profile_page.expand_profile_details
      user_preferences_profile_page.fill_bio(with: "I am a human.")
      user_preferences_profile_page.save

      expect(user_preferences_profile_page.cooked_bio).to have_text("I am a human.")
    end
  end

  describe "hiding profile" do
    it "allows user to hide their profile" do
      SiteSetting.allow_users_to_hide_profile = true

      user_preferences_profile_page.visit(user)
      user_preferences_profile_page.hide_profile
      user_preferences_profile_page.save
      page.refresh

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
      visit("/")

      expect(page).to have_current_path("/u/#{user.username}/preferences/profile")

      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.preferences.profile.enforced_required_fields"),
      )
    end

    it "client-side redirects to the profile page to fill up required fields" do
      visit("/faq")

      expect(page).to have_current_path("/faq")

      click_logo

      expect(page).to have_current_path("/u/#{user.username}/preferences/profile")

      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.preferences.profile.enforced_required_fields"),
      )
    end

    it "disables client-side routing while missing required fields" do
      user_preferences_profile_page.visit(user)

      click_logo

      expect(page).to have_current_path("/u/#{user.username}/preferences/profile")
    end

    it "allows user to fill up required fields" do
      user_preferences_profile_page.visit(user)

      find(".user-field-favourite-pokemon input").fill_in(with: "Mudkip")
      find(".user-field-updated-terms input").check
      find(".save-button .btn-primary").click

      expect(page).to have_selector(".pref-bio")

      visit("/")

      expect(page).to have_current_path("/")
    end

    it "does not allow submitting blank values for required fields" do
      user_preferences_profile_page.visit(user)

      find(".user-field-updated-terms input").check
      find(".save-button .btn-primary").click

      expect(dialog).to be_open
      expect(dialog).to have_content(I18n.t("login.missing_user_field"))

      dialog.click_yes

      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.preferences.profile.enforced_required_fields"),
      )
    end

    it "allows enabling safe-mode" do
      visit("/safe-mode")

      expect(page).to have_current_path("/safe-mode")

      page.find("#btn-enter-safe-mode").click

      expect(page).to have_current_path("/u/#{user.username}/preferences/profile")
    end
  end
end
