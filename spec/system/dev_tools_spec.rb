# frozen_string_literal: true

describe "Discourse dev tools", type: :system do
  it "works" do
    # Open site and check it loads successfully, with no dev-tools
    visit("/latest")
    expect(page).to have_css("#site-logo")
    expect(page).not_to have_css(".dev-tools-toolbar")

    # Enable dev tools, and wait for page to reload
    page.evaluate_script("enableDevTools()")
    expect(page).to have_css(".dev-tools-toolbar")

    # Turn on plugin outlet debugging, and check they appear
    find(".dev-tools-toolbar .toggle-plugin-outlets").click
    expect(page).to have_css(".plugin-outlet-info", minimum: 10)

    # Open a tooltip
    find(".plugin-outlet-info[data-outlet-name=home-logo-contents__before]").hover
    expect(page).to have_css(".plugin-outlet-info__wrapper")

    # Check the outletArgs are shown
    expect(page).to have_css(".plugin-outlet-info__wrapper .key", text: "title")
    expect(page).to have_css(
      ".plugin-outlet-info__wrapper .value",
      text: "\"#{SiteSetting.title}\"",
    )

    # Turn off plugin outlet debugging, and check they disappeared
    find(".dev-tools-toolbar .toggle-plugin-outlets").click
    expect(page).not_to have_css(".plugin-outlet-info")

    # Disable dev tools
    find(".dev-tools-toolbar .disable-dev-tools").click

    # Check reloaded successfully
    expect(page).not_to have_css(".dev-tools-toolbar")
    expect(page).to have_css("#site-logo")
    expect(page).not_to have_css(".dev-tools-toolbar")
  end
end
