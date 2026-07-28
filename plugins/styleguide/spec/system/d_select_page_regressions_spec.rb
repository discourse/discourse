# frozen_string_literal: true

# Regressions found by hand on the select page. Each one is a defect a reader hits within seconds
# of using the page, and none of them was reachable by the existing suite: the specs open a
# control once and assert on its contents, so nothing covered reopening, a control strip, or a
# held value surviving the first open.
describe "UiKit | DSelect page regressions" do
  fab!(:admin)

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

    description = find("[data-test-example-description]", match: :first)
    expect(description).to have_css("code", text: "@value")
    expect(description).to have_no_text("`")
  end

  # A held value survived selection but not a remount. `@load` answers queries and is never asked
  # what a given id is, so with no resolver the only thing left to display an id is whatever the
  # source happened to fetch this session — and `@minChars` means it fetches nothing at rest. The
  # session that picked the value looked correct; leaving the group and coming back showed
  # "en (unavailable)".
  it "keeps a held value readable after leaving and returning to its group" do
    visit "/styleguide/molecules/select?group=data"
    trigger = "[data-identifier='sg-min-chars'][data-trigger]"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-min-chars")

    combobox.select("English (US)")
    expect(page).to have_no_css("#{trigger}[data-unresolved]")

    # Sub-nav clicks, NOT `visit`: a reload would reset the section's own state and leave nothing
    # selected, so the assertions below would pass against an empty field. Changing the group
    # keeps the section mounted while tearing down and rebuilding the select, which is what
    # discards the resolve cache the selection left behind.
    find("[data-test-styleguide-subnav-link='states']").click
    expect(page).to have_no_css(trigger)
    find("[data-test-styleguide-subnav-link='data']").click
    expect(page).to have_css(trigger)

    expect(page).to have_no_css("#{trigger}[data-unresolved]")
    expect(combobox.input.value).to eq("English (US)")
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

    expect(tags.chip_labels).to eq(%w[design-system accessibility])

    tags.trigger.click
    sleep 0.6
    expect(tags.chip_labels).to eq(%w[design-system accessibility])

    tags.press(:escape)
    sleep 0.4
    find(caret).click
    sleep 0.6
    expect(tags.chip_labels).to eq(%w[design-system accessibility])
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

  # Every example that shows a block should show the source for it; the synthesis card shipped
  # without one, so the card a reader is most likely to copy was the one they could not read.
  it "offers the source snippet on the whole-picker example" do
    visit "/styleguide/molecules/select?group=content"
    picker = PageObjects::Components::UiKit::DSelect.by_identifier("sg-content-picker")

    card = find(".styleguide-example", text: "The whole picker")
    expect(card).to have_css("button.styleguide-example__code-toggle")
    expect(picker).to be_present
  end
end
