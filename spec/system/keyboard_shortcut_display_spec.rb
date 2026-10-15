# frozen_string_literal: true

RSpec.describe "Keyboard shortcut display" do
  include ThemeScreenshotMarker

  fab!(:current_user, :admin)

  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(current_user) }

  it "draws every shortcut in the help modal as keycaps" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_page.keyboard.type("?")

    expect(
      browser_root.locator(".keyboard-shortcuts-modal .d-shortcut__key").filter(visible: true),
    ).not_to PlaywrightMatchers.have_count(0)
    expect(
      browser_root.locator(
        ".keyboard-shortcuts-modal .shortcut-key kbd:not(.d-shortcut, .d-shortcut__key)",
      ).filter(visible: true),
    ).to PlaywrightMatchers.have_count(0)

    screenshot_marker(label: "shortcut-help-modal")
  end

  it "keeps the gap between keys in a right-to-left locale" do
    SiteSetting.default_locale = "ar"

    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_page.keyboard.type("?")

    second_key =
      browser_root
        .locator(".keyboard-shortcuts-modal .d-shortcut__key + .d-shortcut__key")
        .filter(visible: true)
        .first
    margin =
      browser_page.evaluate(
        "function(arguments) { return getComputedStyle(arguments[0]).marginLeft }",
        arg: browser_arguments(second_key),
      )

    expect(margin).not_to eq("0px")
  end

  it "draws the shortcut of a composer menu option as keycaps" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator("#create-topic").filter(visible: true).click
    expect(composer).to be_opened

    browser_root.locator(".toolbar-menu__heading-trigger").filter(visible: true).click
    row =
      browser_root.locator(".toolbar-menu__heading-content [data-name='heading-small']").filter(
        visible: true,
      )
    row.hover

    expect(row.locator(".d-shortcut__key")).not_to PlaywrightMatchers.have_count(0)
    expect(row.get_attribute("aria-keyshortcuts")).to match(/(Command|Ctrl)\+/)

    screenshot_marker(label: "shortcut-composer-menu", only: :desktop)
  end

  it "keeps the gap between an option icon and its label" do
    browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
    browser_root.locator("#create-topic").filter(visible: true).click
    expect(composer).to be_opened

    browser_root.locator(".toolbar-menu__options-trigger").filter(visible: true).click
    icon =
      browser_root.locator(
        ".toolbar-menu__options-content [data-name='toggle-spreadsheet'] .d-icon",
      ).filter(visible: true)
    margin =
      browser_page.evaluate(
        "function(arguments) { return getComputedStyle(arguments[0]).marginRight }",
        arg: browser_arguments(icon),
      )

    expect(margin).not_to eq("0px")
  end

  it "draws the admin sidebar search hint as keycaps" do
    browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(
      browser_root.locator(".sidebar-search__shortcut-hint.d-shortcut .d-shortcut__key").filter(
        visible: true,
      ),
    ).to PlaywrightMatchers.have_count(2)
    expect(
      browser_root
        .locator(".sidebar-search__input")
        .filter(visible: true)
        .get_attribute("aria-keyshortcuts"),
    ).to match(/(Command|Ctrl)\+/)

    screenshot_marker(label: "shortcut-sidebar-hint", only: :desktop)
  end
end
