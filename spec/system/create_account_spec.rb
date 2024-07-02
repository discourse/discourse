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
end
