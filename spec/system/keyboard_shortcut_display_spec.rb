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

  it "draws the admin sidebar search hint as keycaps" do
    visit "/admin"

    expect(page).to have_css(".sidebar-search__shortcut-hint.d-shortcut .d-shortcut__key", count: 2)
    expect(find(".sidebar-search__input")["aria-keyshortcuts"]).to match(/(Command|Ctrl)\+/)

    screenshot_marker(label: "shortcut-sidebar-hint", only: :desktop)
  end

  it "documents the component in the styleguide" do
    SiteSetting.styleguide_enabled = true

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

    screenshot_marker(label: "shortcut-styleguide", only: :desktop)
  end
end
