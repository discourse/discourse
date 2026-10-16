# frozen_string_literal: true

describe "Viewing sidebar mobile", mobile: true do
  fab!(:user)
  let(:sidebar_dropdown) { PageObjects::Components::SidebarHeaderDropdown.new }
  let(:composer) { PageObjects::Components::Composer.new }

  before { sign_in(user) }

  it "does not display the sidebar by default" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    expect(sidebar_dropdown).to RSpecPredicates.be_hidden
  end

  it "does not display the keyboard shortcuts button" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar_dropdown.click

    expect(sidebar_dropdown).to RSpecPredicates.be_visible
    expect(sidebar_dropdown).to have_no_keyboard_shortcuts_button
  end

  it "collapses the sidebar when clicking outside of it" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar_dropdown.click

    expect(sidebar_dropdown).to RSpecPredicates.be_visible

    sidebar_dropdown.click_outside

    expect(sidebar_dropdown).to RSpecPredicates.be_hidden
  end

  it "collapses the sidebar when clicking on a link in the sidebar" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar_dropdown.click

    expect(sidebar_dropdown).to RSpecPredicates.be_visible

    sidebar_dropdown.click_topics_link

    expect(sidebar_dropdown).to RSpecPredicates.be_hidden
  end

  it "collapses the sidebar when clicking on a button in the sidebar" do
    browser_page.goto("/latest").tap { SystemBrowserBootstrap.wait_for(browser_page) }

    sidebar_dropdown.click

    expect(sidebar_dropdown).to RSpecPredicates.be_visible

    sidebar_dropdown.click_categories_header_button

    expect(sidebar_dropdown).to RSpecPredicates.be_hidden
  end
end
