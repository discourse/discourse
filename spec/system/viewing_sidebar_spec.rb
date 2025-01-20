# frozen_string_literal: true

describe "Viewing sidebar as logged in user", type: :system do
  fab!(:admin)
  fab!(:user)
  fab!(:category_sidebar_section_link) { Fabricate(:category_sidebar_section_link, user: user) }

  let(:sidebar) { PageObjects::Components::NavigationMenu::Sidebar.new }

  before { sign_in(user) }

  describe "when using the header dropdown navigation menu" do
    before { SiteSetting.navigation_menu = "header dropdown" }

    it "should display the sidebar when `navigation_menu` query param is 'sidebar'" do
      visit("/latest?navigation_menu=sidebar")

      expect(sidebar).to be_visible
      expect(page).not_to have_css(".hamburger-dropdown")
    end
  end

  describe "when using the sidebar navigation menu" do
    before { SiteSetting.navigation_menu = "sidebar" }

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
      expect(links.map(&:text)).to eq(%w[Tematy])
      expect(links.map { |link| link[:title] }).to eq(["Wszystkie tematy"])
    end
  end

  describe "when viewing the 'more' content in the Community sidebar section" do
    let(:more_trigger_selector) do
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-trigger"
    end
    let(:more_links_selector) do
      ".sidebar-section[data-section-name='community'] .sidebar-more-section-content"
    end

    it "toggles the more menu and handles click outside to close it" do
      visit("/latest")

      find(more_trigger_selector).click

      expect(page).to have_selector(more_links_selector, visible: true)

      expect(page).to have_selector("#{more_trigger_selector}[aria-expanded='true']")

      find(more_trigger_selector).click

      expect(page).not_to have_selector(more_links_selector)

      expect(page).to have_selector("#{more_trigger_selector}[aria-expanded='false']")

      find(more_trigger_selector).click

      find(".d-header-wrap").click

      expect(page).not_to have_selector(more_links_selector)
    end
  end

  describe "when viewing the tags section" do
    fab!(:tag1) do
      Fabricate(:tag, name: "tag 1", description: "tag 1 description <script>").tap do |tag|
        Fabricate.times(1, :topic, tags: [tag])
      end
    end

    fab!(:tag2) do
      Fabricate(:tag, name: "tag 2").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
    end

    fab!(:tag3) do
      Fabricate(:tag, name: "tag 3", description: "tag 3 description").tap do |tag|
        Fabricate.times(3, :topic, tags: [tag])
      end
    end

    fab!(:tag4) do
      Fabricate(:tag, name: "tag 4").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
    end

    fab!(:tag5) do
      Fabricate(:tag, name: "tag 5").tap { |tag| Fabricate.times(2, :topic, tags: [tag]) }
    end

    fab!(:tag6) do
      Fabricate(:tag, name: "tag 6").tap { |tag| Fabricate.times(1, :topic, tags: [tag]) }
    end

    it "should not display the tags section when tagging is disabled" do
      SiteSetting.tagging_enabled = false

      visit("/latest")

      expect(sidebar).to be_visible
      expect(sidebar).to have_no_tags_section
    end

    it "should not display the tags section when there are no tags that a user can see" do
      Tag.delete_all

      visit("/latest")

      expect(sidebar).to be_visible
      expect(sidebar).to have_no_tags_section
    end

    it "should display the site's top tags in the tags section when user has not configured any tags" do
      visit("/latest")

      expect(sidebar).to be_visible
      expect(sidebar).to have_tags_section
      expect(sidebar).to have_tag_section_links([tag3, tag2, tag4, tag5, tag1])
      expect(sidebar).to have_tag_section_link_with_title(tag3, "tag 3 description")
      expect(sidebar).to have_tag_section_link_with_title(tag1, "tag 1 description ")
      expect(sidebar).to have_all_tags_section_link
    end

    it "should display the tags configured by the user in alphabetical order" do
      Fabricate(:sidebar_section_link, linkable: tag3, user: user)
      Fabricate(:sidebar_section_link, linkable: tag1, user: user)
      Fabricate(:sidebar_section_link, linkable: tag2, user: user)

      visit("/latest")

      expect(sidebar).to be_visible
      expect(sidebar).to have_tags_section
      expect(sidebar).to have_tag_section_links([tag1, tag2, tag3])
      expect(sidebar).to have_tag_section_link_with_title(tag3, "tag 3 description")
      expect(sidebar).to have_tag_section_link_with_title(tag1, "tag 1 description ")
      expect(sidebar).to have_all_tags_section_link
    end
  end

  it "shouldn't display the panel header for the main sidebar" do
    visit("/latest")
    expect(sidebar).to be_visible
    expect(sidebar).to have_no_panel_header
  end
end
