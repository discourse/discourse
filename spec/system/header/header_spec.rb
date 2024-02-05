# frozen_string_literal: true

RSpec.describe "Glimmer Header", type: :system do
  before { SiteSetting.experimental_glimmer_header_groups = Group::AUTO_GROUPS[:everyone] }

  def click_outside
    find(".d-modal").click(x: 0, y: 0)
  end

  it "renders basics" do
    visit "/"
    expect(page).to have_css("header.d-header")
    expect(page).to have_css("#site-logo")
  end

  it "displays sign up / login buttons" do
    visit "/"
    expect(page).to have_css("button.sign-up-button")
    expect(page).to have_css("button.login-button")

    find("button.sign-up-button").click
    expect(page).to have_css(".d-modal.create-account")

    click_outside

    find("button.login-button").click
    expect(page).to have_css(".d-modal.login-modal")
  end

  it "shows login button when login required" do
    SiteSetting.login_required = true

    visit "/"
    expect(page).to have_css("button.login-button")
    expect(page).to have_css("button.sign-up-button")
    expect(page).not_to have_css("#search-button")
    expect(page).not_to have_css("button.btn-sidebar-toggle")
  end

  context "when logged in and login required" do
    fab!(:current_user) { Fabricate(:user) }

    it "displays current user when logged in and login required" do
      SiteSetting.login_required = true
      sign_in(current_user)

      visit "/"
      expect(page).not_to have_css("button.login-button")
      expect(page).not_to have_css("button.sign-up-button")
      expect(page).to have_css("#search-button")
      expect(page).to have_css("button.btn-sidebar-toggle")
      expect(page).to have_css("#current-user")
    end
  end
end
