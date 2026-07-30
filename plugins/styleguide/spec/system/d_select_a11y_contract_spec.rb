# frozen_string_literal: true

# The gem's RSpec matcher shim is not loaded by `require "playwright"`, so ask for it explicitly.
require "playwright/test"

# The accessibility contract for the core ui-kit `DSelect`, asserted in a real browser.
#
# The rendering tests already assert most of this and pass. This spec exists because passing there
# is not evidence: a rendering test mounts rows before the roving modifier installs, so the suite
# once asserted "keyboard opening activates the first option", passed, and shipped a combobox that
# opened with no cursor at all (SANDBOX-A11Y-REMEDIATION.md, K5 — measured in a browser as
# `seedSaw: "0", optionsNow: 14, ad: "absent"`). Only a real viewport, real CSS heights, a real
# virtualizer and an overlay that renders a frame after the key press can see that class of defect.
#
# Two complementary instruments, because neither is sufficient:
#
#   * `panel_aria_snapshot` — the browser's own accessibility tree, as Playwright's YAML. Catches
#     structure: roles nesting correctly, options not leaking out of the listbox, names resolving,
#     `[selected]` landing on the right row.
#   * `active_descendant_state` — the cursor. Playwright's serializer never reads
#     `aria-activedescendant`, so the snapshot is structurally blind to the thing K5 broke. The
#     boundary is asserted explicitly at the bottom of this file so nobody later mistakes a green
#     snapshot for a verified cursor.
describe "UiKit | DSelect a11y contract" do
  fab!(:admin)

  # Builds Playwright's aria-snapshot matcher directly.
  #
  # Do NOT `include Playwright::Test::Matchers` instead: that module derives its method names by
  # stripping `to_` from every Page/Locator assertion, so Playwright's `to_have_css` arrives as
  # `have_css` and SHADOWS Capybara's. Every `expect(page).to have_css(...)` in the group then dies
  # with `NotImplementedError: Only page and locator assertions are currently implemented`, which
  # names nothing useful and points nowhere near the include. `have_text` and `have_title` collide
  # the same way. Constructing the one matcher we want keeps Capybara's intact.
  #
  # It still polls like any Playwright web-first assertion rather than sampling once.
  def match_aria_snapshot(expected)
    Playwright::Test::Matchers::PlaywrightMatcher.new(:to_match_aria_snapshot, expected)
  end

  let(:static_select) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-static") }
  let(:multi_select) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-multi") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=start"
    expect(page).to have_css("[data-identifier='sg-static'][data-trigger]")
  end

  describe "the accessibility tree" do
    it "exposes the panel as a listbox of named options" do
      static_select.press_in_controller(:down)
      expect(static_select).to have_listbox
      expect(page).to have_css(static_select.option_selector)

      # Partial matching is the default, and the list is windowed by `DVirtualList` — only the
      # mounted slice is in the tree — so this asserts the leading rows rather than all of LOCALES.
      expect(static_select.playwright_locator).to match_aria_snapshot(<<~YAML)
        - listbox:
          - option "English (US)"
          - option "Español"
          - option "Português (Brasil)"
      YAML
    end

    it "reports the chosen row as selected" do
      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)
      find(static_select.option_selector, text: "Español").click

      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)

      expect(static_select.playwright_locator).to match_aria_snapshot(<<~YAML)
        - listbox:
          - option "English (US)"
          - option "Español" [selected]
      YAML
    end

    # Whether the browser's own accessible-name computation shows what a traversal walk shows. If it
    # does, a virtual screen reader adds nothing here that this cannot say with higher fidelity.
    it "names a selected chip the way the platform computes it" do
      multi_select.add("Archived")
      expect(multi_select.chip_labels).to eq(["Archived"])

      snapshot = multi_select.playwright_trigger_locator.aria_snapshot

      expect(snapshot).to include("Archived"),
      "the chip name is absent from the browser-computed tree: #{snapshot}"

      # Recorded because it contradicts the markup's own stated intent: the chip comment in
      # `d-select.gts` promises "Orange, Press Backspace or Delete to remove", but ACCNAME joins
      # `aria-labelledby` targets with a space, so a reader hears one run-on phrase and no comma.
      # Asserted loosely on purpose - this pins the concatenation, not a spoken string.
      expect(snapshot).to match(/Archived Press Backspace/),
      "expected the run-on name ACCNAME actually produces: #{snapshot}"
    end

    it "declares a multi-select listbox as multiselectable" do
      multi_select.open
      expect(multi_select).to have_listbox

      snapshot = multi_select.panel_aria_snapshot
      expect(snapshot).to include("listbox")
      expect(snapshot).to include("option")
    end
  end

  describe "the cursor contract" do
    # The K5 net. Each clause is a distinct defect: no cursor at all, a cursor pointing at an id
    # that no longer resolves, a cursor on something that is not a row, and a cursor whose reported
    # position disagrees with where it actually is.
    it "seeds a resolvable cursor on the first row when opened from the keyboard" do
      static_select.press_in_controller(:down)
      expect(static_select).to have_listbox
      expect(page).to have_css(static_select.option_selector)

      state = static_select.active_descendant_state

      expect(state["status"]).to eq("ok"),
      "expected a resolvable aria-activedescendant, got #{state.inspect}"
      expect(state["index"]).to eq(0)
      expect(state["posinset"]).to eq("1")

      # The count a reader hears has to match the rows that exist. A windowed source that has not
      # finished paging reports "-1" rather than lying with the mounted count.
      expect(state["setsize"]).to satisfy { |size| size == "-1" || size.to_i.positive? },
      "aria-setsize was #{state["setsize"].inspect}"
    end

    it "keeps the cursor resolvable as it moves" do
      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)
      expect(static_select.active_option_index).to eq(0)

      static_select.press_in_controller(:down)

      state = static_select.active_descendant_state
      expect(state["status"]).to eq("ok"), "the cursor stopped resolving: #{state.inspect}"
      expect(state["index"]).to eq(1)
      expect(state["posinset"]).to eq("2")
    end

    it "drops the cursor rather than leaving it dangling when the panel closes" do
      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)
      expect(static_select.active_option_index).to eq(0)

      static_select.press_in_controller(:escape)
      expect(static_select).to have_no_listbox

      # "absent" is correct; "dangling" would mean the attribute outlived the rows it points at,
      # which is how a stale highlight survives a close unnoticed.
      expect(static_select.active_descendant_state["status"]).to eq("absent")
    end

    # A row a keyboard user cannot land on must not consume a position, or the count read out
    # disagrees with the rows reachable — "4 of 6" one press away from "6 of 6".
    it "gives navigable rows contiguous positions" do
      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)

      positions = static_select.mounted_positions
      contiguous = positions.each_cons(2).all? { |a, b| b == a + 1 }

      expect(contiguous).to eq(true),
      "mounted rows reported non-contiguous aria-posinset: #{positions.inspect}"
    end
  end

  # Not a behaviour assertion — a guard on the instruments themselves. If Playwright ever starts
  # serializing the cursor, this fails and the cursor contract above can lean on the snapshot
  # instead of a bespoke script. Until then it documents, in executable form, why both exist.
  describe "the boundary between the two instruments" do
    it "does not capture the cursor in the accessibility tree" do
      static_select.press_in_controller(:down)
      expect(page).to have_css(static_select.option_selector)

      expect(static_select.active_descendant_state["status"]).to eq("ok")

      snapshot = static_select.panel_aria_snapshot
      expect(snapshot).not_to include("activedescendant")
      expect(snapshot).not_to include("[active]")
    end
  end
end
