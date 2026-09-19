# frozen_string_literal: true

RSpec.describe "Styleguide shortcut page" do
  include ThemeScreenshotMarker

  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  it "documents the component in the styleguide" do
    visit "/styleguide/atoms/shortcut"

    %w[keycaps block string_form spellings keyboard_gate].each do |card|
      expect(page).to have_css(
        ".styleguide-example__title",
        text: I18n.t("js.styleguide.sections.shortcut.#{card}_example"),
      )
    end
    expect(page).to have_css(".styleguide-shortcut-spellings tbody tr .d-shortcut", count: 9)
    expect(page).to have_css(".styleguide-example__result", text: "true")
    expect(page).to have_css("[aria-keyshortcuts]", minimum: 2)

    if ENV["TAKE_SCREENSHOTS"] == "1"
      page.scroll_to(find(".styleguide-shortcut-spellings"), align: :center)
    end
    screenshot_marker(label: "shortcut-styleguide", only: :desktop)
  end
end
