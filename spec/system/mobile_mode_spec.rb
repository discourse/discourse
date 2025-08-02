# frozen_string_literal: true

RSpec.describe "Viewport-based mobile mode", type: :system do
  before { SiteSetting.viewport_based_mobile_mode = true }

  it "has both stylesheets, and updates classes at runtime" do
    visit "/"

    mobile_stylesheet = find("link[rel=stylesheet][href*='stylesheets/mobile']", visible: false)
    desktop_stylesheet = find("link[rel=stylesheet][href*='stylesheets/desktop']", visible: false)

    expect(mobile_stylesheet["media"]).to include("max-width")
    expect(desktop_stylesheet["media"]).to include("min-width")

    expect(page).to have_css("html.desktop-view")
    expect(page).not_to have_css("html.mobile-view")

    resize_window(width: 400) do
      expect(page).to have_css("html.mobile-view")
      expect(page).not_to have_css("html.desktop-view")
    end
  end
end
