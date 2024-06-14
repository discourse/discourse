# frozen_string_literal: true

describe "User preferences | Profile", type: :system do
  fab!(:user) { Fabricate(:user, active: true) }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { sign_in(user) }

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
    end

    it "redirects to the profile page to fill up required fields" do
      visit("/")

      expect(page).to have_current_path("/u/bruce0/preferences/profile")

      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.preferences.profile.enforced_required_fields"),
      )
    end

    it "disables client-side routing while missing required fields" do
      user_preferences_profile_page.visit(user)

      find("#site-logo").click

      expect(page).to have_current_path("/u/bruce0/preferences/profile")
    end

    it "allows user to fill up required fields" do
      user_preferences_profile_page.visit(user)

      find(".user-field-favourite-pokemon input").fill_in(with: "Mudkip")
      find(".save-button .btn-primary").click

      visit("/")

      expect(page).to have_current_path("/")
    end
  end
end
