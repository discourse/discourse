# frozen_string_literal: true

RSpec.describe "Keyboard shortcut display" do
  include ThemeScreenshotMarker

  fab!(:current_user, :admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(current_user) }

  it "draws every shortcut in the help modal as keycaps" do
    visit "/"
    page.send_keys("?")

    expect(page).to have_css(".keyboard-shortcuts-modal .d-shortcut__key")
    expect(page).to have_no_css(
      ".keyboard-shortcuts-modal .shortcut-key kbd:not(.d-shortcut, .d-shortcut__key)",
    )

    screenshot_marker(label: "shortcut-help-modal")
  end

  it "keeps the gap between keys in a right-to-left locale" do
    SiteSetting.default_locale = "ar"

    visit "/"
    page.send_keys("?")

    second_key =
      find(".keyboard-shortcuts-modal .d-shortcut__key + .d-shortcut__key", match: :first)
    margin = page.evaluate_script("getComputedStyle(arguments[0]).marginLeft", second_key)

    expect(margin).not_to eq("0px")
  end

  it "draws the shortcut of a composer menu option as keycaps" do
    visit "/"
    find("#create-topic").click
    expect(composer).to be_opened

    find(".toolbar-menu__heading-trigger").click
    row = find(".toolbar-menu__heading-content [data-name='heading-small']")
    row.hover

    expect(row).to have_css(".d-shortcut__key", visible: :all)
    expect(row["aria-keyshortcuts"]).to match(/(Command|Ctrl)\+/)

    screenshot_marker(label: "shortcut-composer-menu", only: :desktop)
  end

  it "keeps the gap between an option icon and its label" do
    visit "/"
    find("#create-topic").click
    expect(composer).to be_opened

    find(".toolbar-menu__options-trigger").click
    icon = find(".toolbar-menu__options-content [data-name='toggle-spreadsheet'] .d-icon")
    margin = page.evaluate_script("getComputedStyle(arguments[0]).marginRight", icon)

    expect(margin).not_to eq("0px")
  end

  it "draws the admin sidebar search hint as keycaps" do
    visit "/admin"

    expect(page).to have_css(".sidebar-search__shortcut-hint.d-shortcut .d-shortcut__key", count: 2)
    expect(find(".sidebar-search__input")["aria-keyshortcuts"]).to match(/(Command|Ctrl)\+/)

    screenshot_marker(label: "shortcut-sidebar-hint", only: :desktop)
  end
end
