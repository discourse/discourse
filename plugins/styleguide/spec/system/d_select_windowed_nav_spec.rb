# frozen_string_literal: true

# Real-browser coverage for keyboard navigation across a WINDOWED DSelect list.
#
# The rendering tests exercise the jump reconcile with virtualization forced on over a small
# list; what they cannot prove is that a page-jump against the real windowing engine scrolls
# the target into the mounted window and lands the cursor on it — with `aria-activedescendant`
# always resolving to a mounted option and never dangling at a scrolled-away id.
#
# The styleguide large-list (5000 options, typeahead) is the only rendered DSelect wide
# enough to window. PageUp/PageDown page the listbox even while the query input holds focus,
# so they drive the jump path here.
describe "UiKit | DSelect windowed navigation" do
  fab!(:admin)

  let(:combobox) do
    PageObjects::Components::UiKit::DSelect.new(".select-examples__large-list .d-combobox__trigger")
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
    expect(page).to have_css(".select-examples__large-list .d-combobox__trigger")
  end

  it "pages the keyboard cursor down and back up through the window without dangling" do
    combobox.open
    expect(page).to have_css("[role='listbox'] [role='option']", wait: 5)

    # PageDown jumps past the mounted window: the reconcile scrolls the target in and lands
    # the cursor on it. `active_index_after_change` returns nil for a dangling id and times out
    # if the cursor never moves, so a returned index proves the jump landed on a mounted option.
    combobox.press_in_controller(:page_down)
    paged_down = combobox.active_index_after_change(nil)
    expect(paged_down).to be > 0

    combobox.press_in_controller(:page_down)
    paged_further = combobox.active_index_after_change(paged_down)
    expect(paged_further).to be > paged_down

    # PageUp brings the cursor back toward the top, still landing on a mounted option.
    combobox.press_in_controller(:page_up)
    expect(combobox.active_index_after_change(paged_further)).to be < paged_further
  end
end
