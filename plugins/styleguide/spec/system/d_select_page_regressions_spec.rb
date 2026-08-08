# frozen_string_literal: true

# Regressions found by hand on the select page. Each one is a defect a reader hits within seconds
# of using the page, and none of them was reachable by the existing suite: the specs open a
# control once and assert on its contents, so nothing covered reopening, a control strip, or a
# held value surviving the first open.
describe "UiKit | DSelect page regressions" do
  fab!(:admin)

  let(:styleguide) { PageObjects::Pages::Styleguide.new }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  # The card prose names arguments and blocks constantly, and they are marked up by backticks in
  # the translation rather than by markup, so a helper has to turn them into elements. It is easy
  # for that to half-work — escaping the string before looking for backticks removes the very
  # character being looked for, and the page then renders literal backticks with no complaint
  # from any other gate.
  it "renders backticked identifiers in card prose as inline code" do
    visit "/styleguide/molecules/select?group=start"

    # Addressed by class: layer 7's reviewed component emits a test hook on the title only, so
    # the BEM class is the stable handle for every other slot.
    description = find(".styleguide-example__description", match: :first)
    expect(description).to have_css("code", text: "@value")
    expect(description).to have_no_text("`")
  end

  # Closing and reopening is the most ordinary thing a reader does, and it was broken: the panel
  # flashed and shut immediately on the second open.
  # Reopening via the caret after the control has already been used. The caret is the obvious
  # affordance to click, and it silently did nothing once focus was sitting in the query input —
  # so the second open of any typeahead appeared to flash and die.
  #
  # The distinction that matters: a COLD caret click (nothing focused) always worked, which is
  # why this went unnoticed. Only the warm path is broken, so the spec has to use the control
  # once before testing it.
  it "reopens from the caret after the input already has focus" do
    visit "/styleguide/molecules/select?group=selection"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-none")
    caret = "[data-identifier='sg-none'][data-trigger] .d-combobox__caret"

    combobox.open
    expect(combobox).to have_listbox

    combobox.press(:escape)
    expect(combobox).to have_no_listbox
    # Escape leaves focus in the input; that is what made the next click fail.
    expect(combobox.input_focused?).to eq(true)

    find(caret).click
    expect(combobox).to have_listbox
  end

  # The held value must survive the first open. The hero's tag picker dropped its first chip the
  # moment the panel opened, because the item list was rebuilt on every read and the engine
  # reconciled the selection against a set whose identities had changed underneath it.
  # The failing path is a click on the trigger BODY, not on the query input: the hero wrapped each
  # field in a `label`, and a label forwards its clicks to the first labelable descendant — which
  # in a multi-select is the first chip's remove button. So aiming at the control deleted a chip.
  # Clicking the caret did it too, which is why this has to exercise both.
  it "keeps every seeded chip when the hero tag picker is opened" do
    visit "/styleguide/molecules/select?group=start"
    tags = PageObjects::Components::UiKit::DSelect.by_identifier("sg-hero-tags")
    caret = "[data-identifier='sg-hero-tags'][data-trigger] .d-combobox__caret"

    expect(tags.chip_labels).to eq(%w[theming accessibility])

    tags.trigger.click
    sleep 0.6
    expect(tags.chip_labels).to eq(%w[theming accessibility])

    tags.press(:escape)
    sleep 0.4
    find(caret).click
    sleep 0.6
    expect(tags.chip_labels).to eq(%w[theming accessibility])
  end

  # The footer card's control strip is the only way to reach the empty and error states it
  # documents, so a button that does nothing makes the card's whole claim unverifiable.
  # The card's whole claim is that the footer survives states with no rows. Each state is its own
  # control, because a select captures its source when its engine is built — a switch that swaps
  # `@load` underneath a live control silently does nothing, which is how this shipped broken.
  it "renders the footer over the populated, empty and failing states alike" do
    visit "/styleguide/molecules/select?group=content"

    populated = PageObjects::Components::UiKit::DSelect.by_identifier("sg-footer")
    populated.open
    expect(page).to have_css(populated.option_selector, wait: 10)
    expect(page).to have_css(populated.in_panel(".d-combobox__footer"))
    populated.press(:escape)

    empty = PageObjects::Components::UiKit::DSelect.by_identifier("sg-footer-empty")
    empty.open
    expect(page).to have_css(empty.in_panel(".d-combobox__empty"), wait: 10)
    expect(page).to have_css(empty.in_panel(".d-combobox__footer"))
    empty.press(:escape)

    broken = PageObjects::Components::UiKit::DSelect.by_identifier("sg-footer-error")
    broken.open
    expect(page).to have_css(broken.in_panel(".d-combobox__error"), wait: 10)
    expect(page).to have_css(broken.in_panel(".d-combobox__footer"))
  end

  # A selected row was marked only by `font-weight`, which is inherited — so any custom `:item`
  # that styled its own label overrode it and the selection stopped being visible. That is every
  # rich row, so a reader could not tell what was already chosen. The marker is now the row's own
  # surface, which consumer markup cannot reach.
  it "marks the selected row even when the consumer styles the row content" do
    visit "/styleguide/molecules/select?group=content"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-selection")

    combobox.open
    expect(page).to have_css(combobox.option_selector, wait: 10)

    marked = page.evaluate_script(<<~JS)
        (function () {
          const row = document.querySelector(
            "#{combobox.option_selector}[aria-selected='true']"
          );
          if (!row) {
            return null;
          }
          return { background: getComputedStyle(row).backgroundColor };
        })()
      JS

    expect(marked).not_to be_nil, "no row reported itself selected"

    # Compared against a sibling rather than a literal, so it holds across themes and colour
    # modes rather than pinning today's palette.
    unselected = page.evaluate_script(<<~JS)
        (function () {
          const row = document.querySelector(
            "#{combobox.option_selector}:not([aria-selected='true'])"
          );
          return row ? getComputedStyle(row).backgroundColor : null;
        })()
      JS
    expect(marked["background"]).not_to eq(unselected)
  end

  it "lets the user compare timezone offsets without repeating decorative icons" do
    visit "/styleguide/molecules/select?group=content"
    examples = PageObjects::Components::SelectExamples.new

    begin
      examples.open_computed_timezones
      expect(examples).to have_timezone_offset_badges(minimum: 3)
      expect(examples).to have_no_timezone_clock_icons
      expect(examples).to have_no_computed_dividers

      initial_times = examples.computed_times
      examples.move_computed_clock_near_next_minute
      sleep 1.5
      expect(examples.computed_times).not_to eq(initial_times)

      examples.close_open_panel
    ensure
      examples.restore_computed_clock
    end

    examples.open_divided_timezones
    expect(examples).to have_timezone_dividers(minimum: 2)
  end

  it "shows each option's icon in the icon-following menu" do
    visit "/styleguide/molecules/select?group=appearance"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-icon-follows")

    # `open` clicks the query input; this example is a `static` variant, which has none.
    combobox.open_trigger

    expect(all(combobox.option_selector, minimum: 1)).to all(have_css(".d-icon"))
  end

  it "shows each example module's source across the select groups" do
    examples = {
      "start" => %w[sg-default DefaultSelectExample],
      "data" => %w[sg-min-chars MinimumCharactersSelectExample],
      "content" => %w[sg-content-picker WholePickerSelectExample],
      "pickers" => %w[sg-reviewers ReviewersSelectExample],
    }

    examples.each do |group, (identifier, component_name)|
      visit "/styleguide/molecules/select?group=#{group}"
      styleguide.show_example_source_by_trigger(identifier)
      expect(styleguide).to have_example_source_by_trigger(
        identifier,
        text: "export default class #{component_name}",
      )
    end
  end
end
