# frozen_string_literal: true

# The one part of the panel's tab order that ONLY a real browser can show.
#
# Chrome 127+ adopts a scroll container as a tab stop when it holds no focusable descendants, so
# that a list which can only be read by scrolling stays reachable. The windowed listbox is exactly
# that shape — in `active` roving mode its options carry no tabindex — so the viewport is held out
# of the sequence with an explicit `tabindex="-1"`, which is legitimate here because the rows are
# already reachable with the arrow keys from the combobox.
#
# The adoption is invisible to every JS-level check: such an element reports `tabIndex === -1` and
# matches no focusable selector, indistinguishable from one that opted out. That also rules out
# QUnit — `@ember/test-helpers`' `tab()` picks candidates by `tabIndex >= 0`, so it would skip the
# scroller whether or not the fix were present and pass either way. Pressing Tab in a real browser
# is the only thing that reveals it.
#
# Everything else about `inlineTabOrder` — entering the panel, leaving it for the trigger's
# neighbour, Shift+Tab, and the fall-through when a panel offers no stop — is covered far more
# cheaply in `tests/integration/components/float-kit/tab-order-inline-test.gjs`.
#
# Needs a panel with TWO stops of its own. With a single stop the panel's own Tab handling takes
# the press before the scroller could ever see it, which masks the suppression; with a filter AND
# a footer, the press between them is a native one and an adopted scroller sits in the middle of
# it. The `sg-tab-order` example exists to provide that shape.
describe "UiKit | DSelect panel tab order" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
  end

  def visit_group(group, identifier)
    visit "/styleguide/molecules/select?group=#{group}"
    expect(page).to have_css("[data-identifier='#{identifier}'][data-trigger]")
  end

  let(:combobox) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-tab-order") }

  it "steps from the filter to the footer without stopping on the list's scroll viewport" do
    visit_group("keyboard", "sg-tab-order")

    combobox.open_trigger
    expect(combobox).to have_listbox
    expect(combobox).to be_panel_input_focused

    # The scroller lies between the filter and the footer in the DOM. Without its `tabindex="-1"`
    # this press stops on it instead — verified by removing the suppression and watching exactly
    # this assertion fail.
    combobox.press(:tab)

    expect(combobox).to be_footer_control_focused
    expect(combobox).to be_list_scroller_blurred
    # Focus moving inside the panel is not focus leaving the widget, so the menu stays open and
    # the control the reader is reaching for still exists.
    expect(combobox).to have_listbox
  end

  # The fall-through, which is what makes `@inlineTabOrder` safe to leave on for every variant.
  # It also cannot be isolated in a component test: a bare `DMenu` still has its older
  # `forwardTabToContent`, which swallows the press on a panel with nothing focusable in it, and
  # only DSelect's query input stops that from happening. So the real arrangement is the only
  # place the fall-through is observable.
  it "lets Tab leave a select whose panel offers no stop of its own" do
    visit_group("start", "sg-default")
    plain = PageObjects::Components::UiKit::DSelect.by_identifier("sg-default")

    plain.open
    expect(plain).to have_listbox

    plain.press(:tab)

    # A list is read with the arrow keys, so Tab passes over the whole widget rather than being
    # captured by a panel that has nothing to offer it.
    expect(plain).to be_widget_blurred
  end
end
