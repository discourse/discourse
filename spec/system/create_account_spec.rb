# frozen_string_literal: true

describe "Create account", type: :system do
  it "creates a user account" do
    visit "/"
    click_button "Sign Up"
    expect(page).to have_css(".d-modal.create-account")

    find("#new-account-email").fill_in with: "test@example.com"

    find("#new-account-username").fill_in with: "user1"
    expect(page.find("#username-validation")).to have_content("Your username is available")

    find("#new-account-password").fill_in with: "secret-password"

    find(".d-modal.create-account").click_button "Sign Up"
    expect(page).to have_no_css(".d-modal.create-account")

    user = User.last
    expect(user.username).to eq("user1")
    expect(user.emails).to eq(["test@example.com"])
  end

  context "when the site has custom user fields" do
    before do
      Fabricate(:user_field, name: "Favorite Avenger", requirement: "on_signup")
      Fabricate(:user_field, name: "Favorite Power Ranger", requirement: "for_all_users")
      Fabricate(:user_field, name: "Favorite Pokemon", requirement: "for_existing_users")
      Fabricate(:user_field, name: "Favorite Jedi", requirement: "optional")
    end

    it "displays the correct user fields" do
      visit "/"
      click_button "Sign Up"

      custom_fields = find("#login-form .user-fields")

      expect(custom_fields).to have_css(".user-field-favorite-avenger")
      expect(custom_fields).to have_css(".user-field-favorite-power-ranger")
      expect(custom_fields).to have_no_css(".user-field-favorite-pokemon")
      expect(custom_fields).to have_css(".user-field-favorite-jedi")
    end
  end
end
