# frozen_string_literal: true

describe "User preferences | Profile", type: :system do
  fab!(:user) { Fabricate(:user, active: true) }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

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

  describe "enforcing required fields" do
    context "when there's a field required for all users" do
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
        find(".save-button .btn-primary").click

        expect(page).to have_selector(".pref-bio")

        visit("/")

        expect(page).to have_current_path("/")
      end

      it "allows enabling safe-mode" do
        visit("/safe-mode")

        expect(page).to have_current_path("/safe-mode")

        page.find("#btn-enter-safe-mode").click

        expect(page).to have_current_path("/u/#{user.username}/preferences/profile")
      end
    end

    context "when there's a field for existing users predating the user" do
      before do
        UserRequiredFieldsVersion.create!
        UserField.create!(
          field_type: "text",
          name: "Favourite Pokemon",
          description: "Hint: It's Mudkip.",
          requirement: :for_existing_users,
          editable: true,
          created_at: user.created_at - 1.day,
        )
      end

      it "does not enforce filling up the field for the new user" do
        visit("/")

        expect(page).to have_current_path("/")
      end
    end
  end
end
