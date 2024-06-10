# frozen_string_literal: true

describe "User preferences | Profile", type: :system do
  fab!(:user) { Fabricate(:user, active: true) }
  let(:user_preferences_profile_page) { PageObjects::Pages::UserPreferencesProfile.new }
  let(:user_preferences_page) { PageObjects::Pages::UserPreferences.new }

  before { sign_in(user) }

  shared_examples "enforced required fields" do
    before do
      UserRequiredFieldsVersion.create!
      UserField.create!(
        field_type: "text",
        name: "Favourite Pokemon",
        description: "Hint: It's Mudkip.",
        requirement: 1,
        editable: true,
      )
    end

    it "allows user to fill up required fields" do
      visit("/")

      expect(page).to have_selector(
        ".alert-error",
        text:
          "You are required to provide additional information before continuing to use this site.",
      )

      find(".user-field-favourite-pokemon input").fill_in(with: "Mudkip")
      find(".save-button .btn-primary").click

      visit("/")

      expect(page).to have_text("You're all caught up!")
    end
  end

  context "when desktop" do
    include_examples "enforced required fields"
  end

  context "when mobile", mobile: true do
    include_examples "enforced required fields"
  end
end
