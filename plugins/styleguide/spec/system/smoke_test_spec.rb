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
      { href: "/molecules/roving-focus", title: "Roving focus" },
      { href: "/molecules/select", title: "Select" },
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

  it "lets the user view the select examples" do
    visit "/styleguide/molecules/select?group=start"

    expect(styleguide).to have_heading("Select")
    screenshot_marker(label: "styleguide-select")

    select = PageObjects::Components::UiKit::DSelect.by_identifier("sg-default")
    select.open
    expect(page).to have_text("Draft")
    screenshot_marker(label: "styleguide-select-open", only: :desktop)
  end

  it "shows the large virtualized list at the top and scrolled deep into the list" do
    visit "/styleguide/molecules/select?group=limits"
    expect(styleguide).to have_heading("Select")

    large_list = PageObjects::Components::UiKit::DSelect.by_identifier("sg-large-list")
    large_list.open
    expect(page).to have_css(large_list.option_selector)
    screenshot_marker(label: "styleguide-select-large-window", only: :desktop)

    large_list.reveal_to_index(999)
    screenshot_marker(label: "styleguide-select-large-deep", only: :desktop)
  end

  it "shows options grouped under section headers" do
    visit "/styleguide/molecules/select?group=content"
    expect(styleguide).to have_heading("Select")

    grouped = PageObjects::Components::UiKit::DSelect.by_identifier("sg-grouped")
    grouped.open
    expect(page).to have_css(grouped.in_panel(".d-combobox__group-header"), minimum: 2)
    screenshot_marker(label: "styleguide-select-grouped", only: :desktop)
  end

  it "shows a pinned footer below the option list" do
    visit "/styleguide/molecules/select?group=content"
    expect(styleguide).to have_heading("Select")

    footer = PageObjects::Components::UiKit::DSelect.by_identifier("sg-footer")
    footer.open
    expect(page).to have_css(footer.in_panel(".d-combobox__panel > .d-combobox__footer"))
    screenshot_marker(label: "styleguide-select-footer", only: :desktop)
  end

  it "shows the picker gallery and a category row with its badge, count and lock" do
    visit "/styleguide/molecules/select?group=pickers"
    expect(styleguide).to have_heading("Select")
    screenshot_marker(label: "styleguide-select-pickers", only: :desktop)

    # The category row is the page's most visible custom row and the one shaped to match core's
    # own: the badge carries the topic count and the restricted lock, with the description on a
    # second line.
    categories = PageObjects::Components::UiKit::DSelect.by_identifier("sg-categories")
    categories.open_trigger
    expect(page).to have_css(categories.in_panel(".select-showcases__category-status .topic-count"))
    expect(page).to have_css(categories.in_panel(".select-showcases__category-desc"))
    screenshot_marker(label: "styleguide-select-category", only: :desktop)
  end

  it "lets the user compare the color palettes" do
    visit "/styleguide/molecules/select?group=pickers"
    colors = PageObjects::Components::UiKit::DSelect.by_identifier("sg-colors")

    colors.open_trigger

    expect(colors).to have_listbox
    screenshot_marker(label: "styleguide-select-colors", only: :desktop)
  end

  it "shows the muted source-error state" do
    visit "/styleguide/molecules/select?group=states"
    expect(styleguide).to have_heading("Select")

    # A button-variant trigger has no inline input, so open it directly rather than via the
    # typeahead-oriented page object.
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-error")
    combobox.open_trigger
    expect(page).to have_css(
      combobox.in_panel(".d-combobox__error .d-icon-triangle-exclamation"),
      wait: 5,
    )
    screenshot_marker(label: "styleguide-select-error", only: :desktop)
  end

  it "shows disabled options and a limit message at the selection maximum" do
    visit "/styleguide/molecules/select?group=selection"
    expect(styleguide).to have_heading("Select")

    maximum = PageObjects::Components::UiKit::DSelect.by_identifier("sg-maximum")
    maximum.open
    expect(page).to have_css(maximum.in_panel(".d-combobox__panel .d-combobox__limit"))
    expect(page).to have_css(maximum.in_panel("[role='option'][aria-disabled='true']"))
    screenshot_marker(label: "styleguide-select-maximum", only: :desktop)
  end

  it "shows a first-class none row in the single-select list" do
    visit "/styleguide/molecules/select?group=selection"
    expect(styleguide).to have_heading("Select")

    none = PageObjects::Components::UiKit::DSelect.by_identifier("sg-none")
    none.open
    # The listbox renders in a portal, not inside the example wrapper.
    expect(page).to have_css(none.in_panel("[role='option'].--none"))
    screenshot_marker(label: "styleguide-select-none", only: :desktop)
  end

  it "shows an icon-only trigger whose icon reflects the selection" do
    visit "/styleguide/molecules/select?group=appearance"
    expect(styleguide).to have_heading("Select")

    expect(page).to have_css(
      "[data-identifier='sg-icon-only'][data-trigger].--icon-only .d-combobox__leading-icon",
    )
    page.scroll_to(find("[data-identifier='sg-icon-only'][data-trigger]"), align: :center)
    # Open it: the dropdown must size to its own options, not the compact trigger, so labels
    # are not clipped.
    icon_only = PageObjects::Components::UiKit::DSelect.by_identifier("sg-icon-only")
    icon_only.open_trigger
    expect(page).to have_css(icon_only.option_selector, text: "Watching")
    screenshot_marker(label: "styleguide-select-icon-only", only: :desktop)
  end

  it "shows a custom selection that becomes an editable label on open" do
    visit "/styleguide/molecules/select?group=content"
    expect(styleguide).to have_heading("Select")

    # Resting: the :selection block renders the compact avatar + name summary.
    expect(page).to have_css(
      "[data-identifier='sg-selection'][data-trigger] .d-combobox__presentation .select-examples__avatar",
    )
    page.scroll_to(find("[data-identifier='sg-selection'][data-trigger]"), align: :center)
    screenshot_marker(label: "styleguide-select-selection-resting", only: :desktop)

    # Open: the custom markup gives way to the plain editable label in the filter input.
    selection = PageObjects::Components::UiKit::DSelect.by_identifier("sg-selection")
    selection.open_trigger
    expect(page).to have_css(selection.option_selector, text: "Maya Alvarez")
    expect(page).to have_no_css(
      "[data-identifier='sg-selection'][data-trigger] .d-combobox__presentation",
    )
    screenshot_marker(label: "styleguide-select-selection-open", only: :desktop)
  end

  it "places the caret in the typeahead on click instead of selecting the whole value" do
    visit "/styleguide/molecules/select?group=start"
    expect(styleguide).to have_heading("Select")

    # The first example is the default typeahead: the chosen label renders inside the input.
    typeahead = first(".select-examples__control")
    typeahead.find(".d-combobox__input").click
    find("[role='option']", text: "Draft").click
    expect(typeahead).to have_field(with: "Draft")

    label_fully_selected = lambda { page.evaluate_script(<<~JS) }
          (() => {
            const input = document.querySelector(
              ".select-examples__control .d-combobox__input"
            );
            return (
              document.activeElement === input &&
              input.value.length > 0 &&
              input.selectionStart === 0 &&
              input.selectionEnd === input.value.length
            );
          })()
        JS

    # Clicking directly on the label text must place the caret there, not select the whole
    # value (the reported bug: a click ends up highlighting the entire label).
    find(".styleguide-contents .d-page-header__title").click # blur to a resting, filled field
    typeahead.find(".d-combobox__input").click
    expect(page).to have_css("[role='listbox']")
    expect(label_fully_selected.call).to eq(false)

    # Clicking the chevron opens via a programmatic focus; it must not select-all either.
    find(".styleguide-contents .d-page-header__title").click
    typeahead.find(".d-combobox__caret").click
    expect(page).to have_css("[role='listbox']")
    expect(label_fully_selected.call).to eq(false)
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
