# frozen_string_literal: true

describe "Viewing sidebar", type: :system do
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user) }

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(user) }

  describe "when using the legacy navigation menu" do
    before { SiteSetting.navigation_menu = "legacy" }

    it "should display the sidebar when `navigation_menu` query param is 'sidebar'" do
      visit("/latest?navigation_menu=sidebar")

      expect(sidebar).to be_visible
      expect(sidebar).to have_category_section_link(category_sidebar_section_link.linkable)
      expect(page).not_to have_css(".hamburger-dropdown")
    end

    it "should display the sidebar dropdown menu when `navigation_menu` query param is 'header_dropdown'" do
      visit("/latest?navigation_menu=header_dropdown")

      expect(sidebar).to be_not_visible

      header_dropdown = PageObjects::Components::SidebarHeaderDropdown.new
      header_dropdown.click

      expect(header_dropdown).to be_visible
    end
  end

  describe "when using the header dropdown navigation menu" do
    before { SiteSetting.navigation_menu = "header dropdown" }

    it "should display the sidebar when `navigation_menu` query param is 'sidebar'" do
      visit("/latest?navigation_menu=sidebar")

      expect(sidebar).to be_visible
      expect(page).not_to have_css(".hamburger-dropdown")
    end

    it "should display the legacy dropdown menu when `navigation_menu` query param is 'legacy'" do
      visit("/latest?navigation_menu=legacy")

      expect(sidebar).to be_not_visible

      legacy_header_dropdown = PageObjects::Components::LegacyHeaderDropdown.new
      legacy_header_dropdown.click

      expect(legacy_header_dropdown).to be_visible
    end
  end

  describe "when using the sidebar navigation menu" do
    before { SiteSetting.navigation_menu = "sidebar" }

    it "should display the legacy dropdown menu when `navigation_menu` query param is 'legacy'" do
      visit("/latest?navigation_menu=legacy")

      expect(sidebar).to be_not_visible

      legacy_header_dropdown = PageObjects::Components::LegacyHeaderDropdown.new
      legacy_header_dropdown.click

      expect(legacy_header_dropdown).to be_visible
    end

    it "should display the sidebar dropdown menu when `navigation_menu` query param is 'header_dropdown'" do
      visit("/latest?navigation_menu=header_dropdown")

      expect(sidebar).to be_not_visible

      header_dropdown = PageObjects::Components::SidebarHeaderDropdown.new
      header_dropdown.click

      expect(header_dropdown).to be_visible
    end
  end

  describe "Community sidebar section", type: :system do
    fab!(:user) { Fabricate(:user, locale: "pl_PL") }
    fab!(:translation_override) do
      TranslationOverride.create!(
        locale: "pl_PL",
        translation_key: "js.sidebar.sections.community.links.topics.content",
        value: "Tematy",
      )
      TranslationOverride.create!(
        locale: "pl_PL",
        translation_key: "js.sidebar.sections.community.links.topics.title",
        value: "Wszystkie tematy",
      )
    end

    before { SiteSetting.allow_user_locale = true }

    it "has correct translations" do
      sign_in user
      visit("/latest")
      links = page.all("#sidebar-section-content-community .sidebar-section-link-wrapper a")
      expect(links.map(&:text)).to eq(%w[Tematy Wysłane])
      expect(links.map { |link| link[:title] }).to eq(
        ["Wszystkie tematy", "Moja ostatnia aktywność w temacie"],
      )
    end
  end
end
