# frozen_string_literal: true

describe "bootstrap_error_pages" do
  before { SiteSetting.bootstrap_error_pages = true }

  it "boots ember for non-existent route" do
    visit "/foobar"
    expect(page).to have_css("#site-logo")
    expect(page).to have_css("div.page-not-found")
    expect(page).not_to have_css("body.no-ember")
  end

  it "boots ember for non-existent topic" do
    visit "/t/999999999999"
    expect(page).to have_css("#site-logo")
    expect(page).to have_css("div.page-not-found")
    expect(page).not_to have_css("body.no-ember")
  end
end
