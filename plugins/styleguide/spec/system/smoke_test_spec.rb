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
      { href: "/molecules/context-menu", title: "Context menu" },
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
      { href: "/molecules/tabs", title: "Tabs" },
      { href: "/molecules/overflow-controls", title: "Overflow controls" },
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

  it "renders the tabs examples" do
    visit "/styleguide/molecules/tabs"

    expect(styleguide).to have_heading("Tabs")
    expect(page).to have_css(".d-tabs [role='tablist']", count: 4)
    expect(page).to have_css(".d-tabs [role='tab'][aria-selected='true']", count: 4)
    expect(page).to have_css(".styleguide-tabs.--vertical [aria-orientation='vertical']")
    expect(page).to have_css(".styleguide-tabs.--narrow .d-overflow-controls__btn.--right")
    screenshot_marker(label: "styleguide-tabs")
  end

  it "renders the overflow controls examples" do
    visit "/styleguide/molecules/overflow-controls"

    expect(styleguide).to have_heading("Overflow controls")
    expect(page).to have_css(".d-overflow-controls", count: 4)
    expect(page).to have_css(".d-overflow-controls__btn.--right", minimum: 3)
    expect(page).to have_css(".d-overflow-controls__btn.--down")
    expect(page).to have_css(".d-overflow-controls.--owned-scroller ul[data-d-scroll-overflow]")
    screenshot_marker(label: "styleguide-overflow-controls")
  end

  it "renders the overflowing navigation bar example" do
    visit "/styleguide/molecules/navigation-bar"

    expect(page).to have_css(
      ".horizontal-overflow-nav .d-overflow-controls__btn.horizontal-overflow-nav__scroll-right",
    )
    expect(page).to have_css(".horizontal-overflow-nav .nav-pills[data-d-scroll-overflow]")
    screenshot_marker(label: "styleguide-navigation-bar-overflow")
  end

  it "renders the index page correctly on a site with no default color schemes" do
    SiteSetting.default_theme_id = Fabricate(:theme).id
    visit "/styleguide"

    expect(styleguide).to have_heading("Styleguide")
    # There is nothing to switch to, so the selector hides itself rather than offering a no-op.
    expect(styleguide).to have_no_color_selector
  end

  # uses the sections hash to check the expected heading on each page
  context "when testing the available pages" do
    before do
      SiteSetting.styleguide_enabled = true
      sign_in(admin)
    end

    it "renders the /syntax/bem page correctly" do
      item = sections.fetch("syntax").find { |candidate| candidate[:href] == "/syntax/bem" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/typography page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/typography" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/font-scale page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/font-scale" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/buttons page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/buttons" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/colors page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/colors" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/icons page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/icons" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/forms page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/forms" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/spinners page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/spinners" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/otp page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/otp" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/date-time-inputs page correctly" do
      item =
        sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/date-time-inputs" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/dropdowns page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/dropdowns" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/topic-link page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/topic-link" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/segmented-control page correctly" do
      item =
        sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/segmented-control" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /atoms/shortcut page correctly" do
      item = sections.fetch("atoms").find { |candidate| candidate[:href] == "/atoms/shortcut" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/bread-crumbs page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/bread-crumbs" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/categories page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/categories" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/char-counter page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/char-counter" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/combo-button page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/combo-button" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/context-menu page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/context-menu" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/empty-state page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/empty-state" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/menus page correctly" do
      item = sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/menus" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/navigation-bar page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/navigation-bar" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/navigation-stacked page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/navigation-stacked" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/post-menu page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/post-menu" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/reorderable-list page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/reorderable-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/roving-focus page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/roving-focus" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/signup-cta page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/signup-cta" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/multi-select page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/multi-select" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/toasts page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/toasts" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/dialog page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/dialog" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/drag-and-drop page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/drag-and-drop" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/tooltips page correctly" do
      item =
        sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/tooltips" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/topic-list-item page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/topic-list-item" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/topic-notifications page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/topic-notifications" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/topic-timer-info page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/topic-timer-info" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/virtual-list page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/virtual-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/tabs page correctly" do
      item = sections.fetch("molecules").find { |candidate| candidate[:href] == "/molecules/tabs" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /molecules/overflow-controls page correctly" do
      item =
        sections
          .fetch("molecules")
          .find { |candidate| candidate[:href] == "/molecules/overflow-controls" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/post page correctly" do
      item = sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/post" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/post-list page correctly" do
      item =
        sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/post-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/post-oneboxes page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/post-oneboxes" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/topic-map page correctly" do
      item =
        sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/topic-map" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/topic-footer-buttons page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/topic-footer-buttons" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/topic-list page correctly" do
      item =
        sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/topic-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/basic-topic-list page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/basic-topic-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/categories-list page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/categories-list" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/chat page correctly" do
      item = sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/chat" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/docked-composer page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/docked-composer" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/modal page correctly" do
      item = sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/modal" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/navigation page correctly" do
      item =
        sections.fetch("organisms").find { |candidate| candidate[:href] == "/organisms/navigation" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/site-header page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/site-header" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
    end

    it "renders the /organisms/more-topics page correctly" do
      item =
        sections
          .fetch("organisms")
          .find { |candidate| candidate[:href] == "/organisms/more-topics" }
      visit "/styleguide/#{item[:href]}"

      expect(styleguide).to have_heading(item[:title])
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
