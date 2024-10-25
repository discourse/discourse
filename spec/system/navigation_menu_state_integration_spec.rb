# frozen_string_literal: true

describe "Navigation menu states", type: :system do
  fab!(:current_user) { Fabricate(:user) }
  let!(:sidebar_navigation) { PageObjects::Components::NavigationMenu::Sidebar.new }
  let!(:header_dropdown) { PageObjects::Components::NavigationMenu::HeaderDropdown.new }

  before { sign_in(current_user) }

  context "when navigation_menu is 'header dropdown'" do
    before { SiteSetting.navigation_menu = "header dropdown" }

    it "does not show the sidebar" do
      visit "/"
      expect(sidebar_navigation).to be_not_visible
    end

    it "opens and closes the hamburger menu from the toggle" do
      visit "/"
      expect(header_dropdown).to be_visible
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
        visit "/admin"
        expect(sidebar_navigation).to be_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_not_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_visible
        expect(find(sidebar_navigation.header_toggle_css)).to have_css(".d-icon-discourse-sidebar")
      end

      it "shows the hamburger menu and allows toggling it, which shows the MAIN_PANEL only" do
        visit "/admin"
        expect(header_dropdown).to be_visible
        header_dropdown.open
        expect(header_dropdown).to have_dropdown_visible
        expect(header_dropdown).to have_sidebar_panel("main")
        expect(header_dropdown).to have_no_sidebar_panel("admin")
        header_dropdown.close
        expect(header_dropdown).to have_no_dropdown_visible
      end

      it "shows the sidebar on other admin pages" do
        visit "/admin"
        expect(sidebar_navigation).to be_visible
        visit "/admin/site_settings/category/all_results"
        expect(sidebar_navigation).to be_visible
        visit "/admin/reports"
        expect(sidebar_navigation).to be_visible
      end

      context "when the user is not in admin_sidebar_enabled_groups" do
        before { SiteSetting.admin_sidebar_enabled_groups = "" }

        it "does not show the sidebar" do
          visit "/admin"
          expect(sidebar_navigation).to be_not_visible
        end
      end
    end
  end

  context "when navigation_menu is 'sidebar'" do
    before { SiteSetting.navigation_menu = "sidebar" }

    it "shows the sidebar" do
      visit "/"
      expect(sidebar_navigation).to be_visible
    end

    it "does not show the hamburger menu" do
      visit "/"
      expect(header_dropdown).to be_not_visible
    end

    it "opens and closes the sidebar from the toggle" do
      visit "/"
      sidebar_navigation.click_header_toggle
      expect(sidebar_navigation).to be_not_visible
      sidebar_navigation.click_header_toggle
      expect(sidebar_navigation).to be_visible
    end

    context "for admins" do
      fab!(:current_user) { Fabricate(:admin, refresh_auto_groups: true) }

      it "shows the sidebar and allows toggling it" do
        visit "/admin"
        expect(sidebar_navigation).to be_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_not_visible
        sidebar_navigation.click_header_toggle
        expect(sidebar_navigation).to be_visible
        expect(find(sidebar_navigation.header_toggle_css)).to have_css(".d-icon-bars")
      end

      it "does not show the hamburger menu" do
        visit "/admin"
        expect(header_dropdown).to be_not_visible
      end

      context "when the user is not in admin_sidebar_enabled_groups" do
        before { SiteSetting.admin_sidebar_enabled_groups = "" }

        it "shows the MAIN_PANEL of the sidebar" do
          visit "/admin"
          expect(sidebar_navigation).to have_no_section("admin-root")
          expect(sidebar_navigation).to have_section("community")
        end

        it "does show the sidebar toggle" do
          visit "/admin"
          expect(page).to have_css(sidebar_navigation.header_toggle_css)
        end
      end
    end
  end
end
