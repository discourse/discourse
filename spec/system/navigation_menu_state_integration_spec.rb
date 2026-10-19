# frozen_string_literal: true

describe "Navigation menu states" do
  fab!(:current_user, :user)
  let!(:sidebar_navigation) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let!(:header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }

  before { sign_in(current_user) }

  context "when navigation_menu is 'header dropdown'" do
    before { SiteSetting.navigation_menu = "header dropdown" }

    it "does not show the sidebar" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(sidebar_navigation).to be_not_visible
    end

    it "opens and closes the hamburger menu from the toggle" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(header_dropdown).to RSpecPredicates.be_visible
      header_dropdown.open
      expect(header_dropdown).to have_dropdown_visible
      expect(header_dropdown).to have_sidebar_panel("main")
      expect(header_dropdown).to have_no_sidebar_panel("admin")
      header_dropdown.close
      expect(header_dropdown).to have_no_dropdown_visible
    end

    context "for admins" do
      fab!(:current_user) { Fabricate(:admin, refresh_auto_groups: true) }

      it "shows the sidebar and allows toggling it" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_not_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        expect(
          browser_root
            .locator(sidebar_navigation.header_toggle_css)
            .filter(visible: true)
            .locator(".d-icon-discourse-sidebar")
            .filter(visible: true),
        ).not_to have_count(0)
      end

      it "shows the hamburger menu and allows toggling it, which shows the MAIN_PANEL only" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(header_dropdown).to RSpecPredicates.be_visible
        header_dropdown.open
        expect(header_dropdown).to have_dropdown_visible
        expect(header_dropdown).to have_sidebar_panel("main")
        expect(header_dropdown).to have_no_sidebar_panel("admin")
        header_dropdown.close
        expect(header_dropdown).to have_no_dropdown_visible
      end

      it "shows the sidebar on other admin pages" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        browser_page
          .goto("/admin/site_settings/category/all_results")
          .tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        browser_page.goto("/admin/reports").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar_navigation).to RSpecPredicates.be_visible
      end
    end
  end

  context "when navigation_menu is 'sidebar'" do
    before { SiteSetting.navigation_menu = "sidebar" }

    it "shows the sidebar" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(sidebar_navigation).to RSpecPredicates.be_visible
    end

    it "does not show the hamburger menu" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      expect(header_dropdown).to be_not_visible
    end

    it "opens and closes the sidebar from the toggle" do
      browser_page.goto("/").tap { SystemBrowserBootstrap.wait_for(browser_page) }
      sidebar_navigation.click_header_toggle
      expect(sidebar_navigation).to be_not_visible
      sidebar_navigation.click_header_toggle
      expect(sidebar_navigation).to RSpecPredicates.be_visible
    end

    context "for admins" do
      fab!(:current_user) { Fabricate(:admin, refresh_auto_groups: true) }

      it "shows the sidebar and allows toggling it" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_not_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to RSpecPredicates.be_visible
        expect(
          browser_root
            .locator(sidebar_navigation.header_toggle_css)
            .filter(visible: true)
            .locator(".d-icon-bars")
            .filter(visible: true),
        ).not_to have_count(0)
      end

      it "does not show the hamburger menu" do
        browser_page.goto("/admin").tap { SystemBrowserBootstrap.wait_for(browser_page) }
        expect(header_dropdown).to be_not_visible
      end
    end
  end
end
