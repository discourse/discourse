# frozen_string_literal: true

RSpec.describe "Styleguide Smoke Test" do
  include ThemeScreenshotMarker

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
      { href: "/atoms/shortcut", title: "Shortcut" },
    ],
    "molecules" => [
      { href: "/molecules/bread-crumbs", title: "Bread Crumbs" },
      { href: "/molecules/categories", title: "Categories" },
      { href: "/molecules/char-counter", title: "Character Counter" },
      { href: "/molecules/combo-button", title: "Combo Button" },
      { href: "/molecules/empty-state", title: "Empty State" },
      { href: "/molecules/menus", title: "Menus" },
      { href: "/molecules/navigation-bar", title: "Navigation Bar" },
      { href: "/molecules/navigation-stacked", title: "Navigation Stacked" },
      { href: "/molecules/post-menu", title: "Post Menu" },
      { href: "/molecules/reorderable-list", title: "Reorderable list" },
      { href: "/molecules/roving-focus", title: "Roving focus" },
      { href: "/molecules/signup-cta", title: "Signup CTA" },
      { href: "/molecules/multi-select", title: "Multi select" },
      { href: "/molecules/toasts", title: "Toasts" },
      { href: "/molecules/dialog", title: "Dialog" },
      { href: "/molecules/drag-and-drop", title: "Drag and drop" },
      { href: "/molecules/tooltips", title: "Tooltips" },
      { href: "/molecules/topic-list-item", title: "Topic List Item" },
      { href: "/molecules/topic-notifications", title: "Topic Notifications" },
      { href: "/molecules/topic-timer-info", title: "Topic Timers" },
      { href: "/molecules/virtual-list", title: "Virtual list" },
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

  it "renders the drag and drop examples" do
    visit "/styleguide/molecules/drag-and-drop"

    expect(styleguide).to have_heading("Drag and drop")
    # The first group renders by default; the rest are behind the group subnav.
    expect(page).to have_css("[data-test-styleguide-group='basics']")
    expect(page).to have_css(".styleguide-drag-and-drop__zone")
    screenshot_marker(label: "styleguide-drag-and-drop")
  end

  # Asserting on each group's own markup, not just its wrapper: the wrapper
  # renders before a broken example inside it throws, so a wrapper-only check
  # passes for a group whose examples never mounted.
  it "renders each drag and drop group's examples" do
    {
      "basics" => ".styleguide-drag-and-drop__swatches",
      "sources" => ".styleguide-drag-and-drop__grip",
      "targets" => ".styleguide-drag-and-drop__zone.--inner",
      "outside" => ".styleguide-drag-and-drop__zone",
      "reacting" => %w[.styleguide-drag-and-drop__panel .styleguide-drag-and-drop__folder],
      "resize" => ".styleguide-drag-and-drop__resizable",
      "gestures" => ".styleguide-drag-and-drop__knob",
    }.each do |group, selectors|
      visit "/styleguide/molecules/drag-and-drop?group=#{group}"

      expect(page).to have_css("[data-test-styleguide-group='#{group}']")
      Array(selectors).each { |selector| expect(page).to have_css(selector) }
    end
  end

  it "labels each drag and drop example with what it demonstrates" do
    visit "/styleguide/molecules/drag-and-drop?group=resize"

    # The separator and the handles are components; the raw edge is a modifier.
    expect(page).to have_css(".styleguide-example__kind", count: 3)
  end

  it "renders the dwell example collapsed and open" do
    visit "/styleguide/molecules/drag-and-drop?group=reacting"

    expect(page).to have_css(".styleguide-drag-and-drop__folder")
    expect(page).to have_no_css(".styleguide-drag-and-drop__folder.--open")
    if ENV["TAKE_SCREENSHOTS"] == "1"
      page.scroll_to(find(".styleguide-drag-and-drop__folder"), align: :center)
    end
    screenshot_marker(label: "styleguide-drag-and-drop-dwell")

    find(".styleguide-drag-and-drop__folder-toggle").click
    expect(page).to have_css(".styleguide-drag-and-drop__folder.--open")
    expect(page).to have_css(".styleguide-drag-and-drop__folder-row", count: 3)
    if ENV["TAKE_SCREENSHOTS"] == "1"
      page.scroll_to(find(".styleguide-drag-and-drop__folder"), align: :center)
    end
    screenshot_marker(label: "styleguide-drag-and-drop-dwell-open")
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
