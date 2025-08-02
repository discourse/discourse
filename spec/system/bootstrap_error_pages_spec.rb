# frozen_string_literal: true

describe "bootstrap_error_pages", type: :system do
  before { SiteSetting.bootstrap_error_pages = true }

  it "boots ember for non-existent route" do
    visit "/foobar"
    expect(page).not_to have_css("body.no-ember")
    expect(page).to have_css("#site-logo")
    expect(page).to have_css("div.page-not-found")
  end

  it "boots ember for non-existent topic" do
    visit "/t/999999999999"
    expect(page).not_to have_css("body.no-ember")
    expect(page).to have_css("#site-logo")
    expect(page).to have_css("div.page-not-found")
  end
end
