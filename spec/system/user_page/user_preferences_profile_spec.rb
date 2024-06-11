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

    it "allows user to fill up required fields" do
      # Redirects to the profile page to fill up missing fields.
      #
      visit("/")

      expect(page).to have_current_path("/u/bruce0/preferences/profile")

      # Shows a notice that the user needs to fill up more fields.
      #
      expect(page).to have_selector(
        ".alert-error",
        text: I18n.t("js.user.preferences.profile.enforced_required_fields"),
      )

      # Prevents user from navigating to other client-side routes.
      #
      find("#site-logo").click

      expect(page).to have_current_path("/u/bruce0/preferences/profile")

      # No longer redirects after filling up the missing fields.
      #
      find(".user-field-favourite-pokemon input").fill_in(with: "Mudkip")
      find(".save-button .btn-primary").click

      visit("/")

      expect(page).to have_current_path("/")
    end
  end
end
