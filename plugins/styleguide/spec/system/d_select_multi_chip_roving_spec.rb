# frozen_string_literal: true

# Real-browser coverage for the core ui-kit `DSelect` multi-select chip arrow-roving. The
# qunit tests (d-select-multi-flip-test.gjs) can't reproduce two things a keyboard user
# actually relies on: the browser's NATIVE activation of a focused button on Enter/Space (a
# synthetic keydown never fires the click), and the real Tab order.
#
# System tests need a real rendered page, and the styleguide's multi `DSelect` example is the
# only one that exists today — so this lives in the styleguide plugin for now. Move it to a
# core `spec/system` once a real core consumer renders `DSelect @multiple`. The page object it
# drives (`PageObjects::Components::UiKit::DSelect`) is core-owned and reusable.
describe "UiKit | DSelect multi-select chip roving" do
  fab!(:admin)

  let(:combobox) { PageObjects::Components::UiKit::DSelect.new(".d-combobox__trigger.--multiple") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
    expect(page).to have_css(".d-combobox__trigger.--multiple")
  end

  # Seeds three chips (Orange, Blue, Red) via the typeahead, leaving focus in the input.
  def add_three_chips
    combobox.add("Orange")
    combobox.add("Blue")
    combobox.add("Red")
    expect(combobox.chips.size).to eq(3)
  end

  it "keeps the query input as the only tab stop and reaches chips by arrow keys" do
    add_three_chips

    # Every remove button is out of the tab order — the input is the sole tab stop.
    expect(combobox.remove_button_tabindexes).to eq(%w[-1 -1 -1])

    combobox.focus_input
    # ArrowLeft at the start of the (empty) query enters the chip nearest the input.
    combobox.press(:left)
    expect(combobox.focused_chip_label).to eq("Red")

    combobox.press(:left)
    expect(combobox.focused_chip_label).to eq("Blue")

    combobox.press(:left)
    expect(combobox.focused_chip_label).to eq("Orange")

    # ArrowLeft at the far (left) edge stays put.
    combobox.press(:left)
    expect(combobox.focused_chip_label).to eq("Orange")

    # ArrowRight walks back toward the input and steps off its edge into the input.
    combobox.press(:right)
    expect(combobox.focused_chip_label).to eq("Blue")
    combobox.press(:right)
    expect(combobox.focused_chip_label).to eq("Red")
    combobox.press(:right)
    expect(combobox.input_focused?).to eq(true)
  end

  it "removes a focused chip with the button's native Enter activation and returns to the input" do
    add_three_chips

    combobox.focus_input
    combobox.press(:left) # onto Red (nearest the input)
    expect(combobox.focused_chip_label).to eq("Red")

    # Enter is the button's NATIVE activation — the case a synthetic keydown can't cover.
    combobox.press(:enter)

    expect(combobox.chip_labels).to eq(%w[Orange Blue])
    expect(combobox.input_focused?).to eq(true)
  end

  it "removes a focused chip with Backspace and moves focus to the previous chip" do
    add_three_chips

    combobox.focus_input
    combobox.press(:left) # Red
    combobox.press(:left) # Blue
    expect(combobox.focused_chip_label).to eq("Blue")

    combobox.press(:backspace)

    expect(combobox.chip_labels).to eq(%w[Orange Red])
    # Focus moves to the chip before the removed one (Primer behavior).
    expect(combobox.focused_chip_label).to eq("Orange")
  end

  it "removes a focused chip with Delete" do
    add_three_chips

    combobox.focus_input
    combobox.press(:left) # Red
    combobox.press(:delete)

    expect(combobox.chip_labels).to eq(%w[Orange Blue])
  end

  it "returns focus to the input when the last chip is removed by keyboard" do
    combobox.add("Orange")
    expect(combobox.chips.size).to eq(1)

    combobox.focus_input
    combobox.press(:left) # onto the only chip
    combobox.press(:backspace)

    expect(combobox.chips.size).to eq(0)
    expect(combobox.input_focused?).to eq(true)
  end

  it "closes the overlay on Escape from a chip, leaving focus on the chip" do
    add_three_chips
    # The multi overlay stays open across adds.
    expect(page).to have_css("[role='listbox']")

    combobox.focus_input
    combobox.press(:left) # onto a chip
    expect(combobox.focused_chip_label).to eq("Red")

    combobox.press(:escape)

    # float-kit owns Escape (document-level capture); it closes the menu and focus stays
    # on the chip, which remains arrow-navigable with the menu closed.
    expect(page).to have_no_css("[role='listbox']")
    expect(combobox.focused_chip_label).to eq("Red")
  end

  it "reopens the menu with ArrowDown from a focused chip, moving focus to the input" do
    add_three_chips
    combobox.focus_input
    combobox.press(:left) # onto a chip
    combobox.press(:escape) # close; focus stays on the chip
    expect(page).to have_no_css("[role='listbox']")
    expect(combobox.focused_chip_label).to eq("Red")

    # ArrowDown is the reopen gesture: jump to the input and open the options.
    combobox.press(:down)

    expect(page).to have_css("[role='listbox']")
    expect(combobox.input_focused?).to eq(true)
  end
end
