# frozen_string_literal: true

RSpec.describe "Local dates toolbar shortcut" do
  include ThemeScreenshotMarker

  fab!(:current_user, :admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(current_user) }

  it "shows the shortcut without hovering the menu row" do
    visit "/"
    find("#create-topic").click
    expect(composer).to be_opened

    find(".toolbar-menu__options-trigger").click

    expect(page).to have_css(
      ".toolbar-menu__options-content [data-name='local-dates'] .d-shortcut",
      visible: :visible,
    )
  end

  it "lays the shortcut out beside the label instead of over it" do
    visit "/"
    find("#create-topic").click
    expect(composer).to be_opened

    find(".toolbar-menu__options-trigger").click
    row = find(".toolbar-menu__options-content [data-name='local-dates']")
    text = row.find(".d-button-label__text")
    chip = row.find(".d-shortcut")

    text_right = page.evaluate_script("arguments[0].getBoundingClientRect().right", text)
    chip_left = page.evaluate_script("arguments[0].getBoundingClientRect().left", chip)

    expect(chip_left).to be >= text_right

    screenshot_marker(label: "shortcut-options-menu-at-rest", only: :desktop)
  end
end
