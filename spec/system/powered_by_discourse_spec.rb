# frozen_string_literal: true

describe "Powered by Discourse", type: :system do
  it "appears when enabled" do
    SiteSetting.show_powered_by = true

    visit "/"
    expect(page).to have_css(".powered-by-discourse")
  end

  it "does not appear on admin routes when enabled" do
    SiteSetting.show_powered_by = true

    visit "/admin"
    expect(page).not_to have_css(".powered-by-discourse")
  end

  it "does not appear on login required route when enabled" do
    SiteSetting.show_powered_by = true
    SiteSetting.login_required = true

    visit "/"
    expect(page).not_to have_css(".powered-by-discourse")
  end

  it "does not appear when disabled" do
    SiteSetting.show_powered_by = false

    visit "/"
    expect(page).not_to have_css(".powered-by-discourse")
  end
end
