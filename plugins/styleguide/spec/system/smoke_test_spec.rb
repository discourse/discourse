# frozen_string_literal: true

RSpec.describe "Styleguide Smoke Test" do
  fab!(:admin)

  let(:styleguide) { PageObjects::Pages::Styleguide.new }

  # keep this hash updated when adding, removing or renaming components
  sections = {
    "syntax" => [{ href: "/syntax/bem", title: "BEM" }],
    "atoms" => [
      { href: "/atoms/typography", title: "Typography" },
      { href: "/atoms/font-scale", title: "Font System" },
      { href: "/atoms/buttons", title: "Buttons" },
      { href: "/atoms/colors", title: "Colors" },
      { href: "/atoms/icons", title: "Icons" },
      { href: "/atoms/forms", title: "Forms" },
      { href: "/atoms/spinners", title: "Spinners" },
      { href: "/atoms/otp", title: "OTP" },
      { href: "/atoms/date-time-inputs", title: "Date/Time inputs" },
      { href: "/atoms/dropdowns", title: "Dropdowns" },
      { href: "/atoms/topic-link", title: "Topic Link and Status" },
      { href: "/atoms/segmented-control", title: "Segmented Control (Button toggle group)" },
    ],
    "molecules" => [
      { href: "/molecules/bread-crumbs", title: "Bread Crumbs" },
      { href: "/molecules/categories", title: "Categories" },
      { href: "/molecules/char-counter", title: "Character Counter" },
      { href: "/molecules/empty-state", title: "Empty State" },
      { href: "/molecules/menus", title: "Menus" },
      { href: "/molecules/navigation-bar", title: "Navigation Bar" },
      { href: "/molecules/navigation-stacked", title: "Navigation Stacked" },
      { href: "/molecules/post-menu", title: "Post Menu" },
      { href: "/molecules/signup-cta", title: "Signup CTA" },
      { href: "/molecules/multi-select", title: "Multi select" },
      { href: "/molecules/toasts", title: "Toasts" },
      { href: "/molecules/dialog", title: "Dialog" },
      { href: "/molecules/tooltips", title: "Tooltips" },
      { href: "/molecules/topic-list-item", title: "Topic List Item" },
      { href: "/molecules/topic-notifications", title: "Topic Notifications" },
      { href: "/molecules/topic-timer-info", title: "Topic Timers" },
    ],
    "organisms" => [
      { href: "/organisms/post", title: "Post" },
      { href: "/organisms/post-list", title: "Post List" },
      { href: "/organisms/post-oneboxes", title: "Post Oneboxes" },
      { href: "/organisms/topic-map", title: "Topic Map" },
      { href: "/organisms/topic-footer-buttons", title: "Topic Footer Buttons" },
      { href: "/organisms/topic-list", title: "Topic List" },
      { href: "/organisms/basic-topic-list", title: "Basic Topic List" },
      { href: "/organisms/categories-list", title: "Categories List" },
      { href: "/organisms/chat", title: "Chat" },
      { href: "/organisms/docked-composer", title: "Docked Composer" },
      { href: "/organisms/modal", title: "Modal" },
      { href: "/organisms/navigation", title: "Navigation" },
      { href: "/organisms/site-header", title: "Site Header" },
      { href: "/organisms/more-topics", title: "More Topics" },
    ],
  }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  # this test will check if the index page is rendering correctly and also ensures that all component pages are
  # declared in the sections hash above
  it "renders the index page correctly and collect information about the available page" do
    visit "/styleguide"
    expect(styleguide).to have_heading("Styleguide")

    existing_sections = {}
    page
      .all(".sidebar-sections.styleguide-panel .sidebar-section[data-section-name]")
      .each do |section_node|
        # Keyed on the section name rather than the header's text: the name is the contract the
        # panel actually declares, where the text depends on translation and on casing applied
        # by the stylesheet.
        section = section_node["data-section-name"].delete_prefix("styleguide-category-")

        existing_sections[section] ||= []
        items = existing_sections[section]

        section_node
          .all(".sidebar-section-link")
          .each do |link|
            items << {
              title: link.find(".sidebar-section-link-content-text").text.strip,
              href: link[:href],
            }
          end
      end

    expect(existing_sections.keys).to match_array(sections.keys)

    sections.each do |section, items|
      items.each do |item|
        existing_items = existing_sections[section]
        existing_item = existing_items.find { |i| i[:title] == item[:title] }

        expect(existing_item).not_to be_nil,
        "Item #{item[:title]} not declared in section #{section}"
        expect(existing_item[:href]).to end_with(item[:href])

        expect(existing_items.size).to eq(items.size),
        "Section #{section} has a different number of items declared then what was found in the index page"
      end
    end
  end

  it "shows the not found page for a section that does not exist" do
    visit "/styleguide/molecules/does-not-exist"

    expect(page).to have_css(".page-not-found")
    expect(styleguide).to have_no_heading("Styleguide")
  end

  it "shows the reader the trail back to the styleguide index" do
    visit "/styleguide/atoms/buttons"

    expect(styleguide).to have_breadcrumb("Styleguide")
    expect(styleguide).to have_breadcrumb("Buttons")
  end

  it "renders the index page correctly on a site with no default color schemes" do
    SiteSetting.default_theme_id = Fabricate(:theme).id
    visit "/styleguide"

    expect(styleguide).to have_heading("Styleguide")
    # There is nothing to switch to, so the selector hides itself rather than offering a no-op.
    expect(styleguide).to have_no_color_selector
  end

  # uses the sections hash to generate a test for each page and check if it renders correctly
  context "when testing the available pages" do
    before do
      SiteSetting.styleguide_enabled = true
      sign_in(admin)
    end

    sections.each do |section, items|
      items.each do |item|
        it "renders the #{section}: #{item[:title]} page correctly" do
          visit "/styleguide/#{item[:href]}"

          expect(styleguide).to have_heading(item[:title])
        end
      end
    end
  end

  context "when the styleguide is enabled for everyone" do
    before do
      Capybara.reset_sessions!
      SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:anonymous_users]
    end

    it "renders a page using HighlightedCode for anonymous users" do
      visit "/styleguide/atoms/font-scale"
      expect(styleguide).to have_heading("Font System")
      expect(page).to have_css("code.hljs")
    end
  end

  context "when the styleguide is only enabled for staff" do
    before { SiteSetting.styleguide_allowed_groups = Group::AUTO_GROUPS[:staff] }

    it "denies access to regular users" do
      user = Fabricate(:user)
      sign_in(user)
      visit "/styleguide"
      expect(page).to have_content("That page doesn’t exist or is private.")
    end

    it "allows access to staff users" do
      moderator = Fabricate(:moderator)
      sign_in(moderator)
      visit "/styleguide"
      expect(styleguide).to have_heading("Styleguide")
    end
  end
end
