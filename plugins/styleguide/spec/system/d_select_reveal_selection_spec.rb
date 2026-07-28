# frozen_string_literal: true

# Reopening a select must show the reader what they already picked. The cursor is seeded from
# the option carrying `aria-selected`, but the roving modifier can only see rows that are
# MOUNTED, and a windowed list mounts a window — so a selection below the fold is invisible to
# the seed, the cursor falls back to the first row, and the list opens at the top with the
# current value nowhere on screen.
describe "UiKit | DSelect reveals the selection on open" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=limits"
  end

  # 5000 rows, so a selection made deep in the list is far outside the window the next open
  # mounts. Scrolling to reach it is what makes this the windowed case rather than the short-list
  # one — a list that fits its viewport would pass without exercising the seed at all.
  it "opens scrolled to a selection made deep in a windowed list" do
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-large-list")

    combobox.open
    expect(page).to have_css(combobox.option_selector, wait: 20)
    combobox.reveal_to_index(120)

    deep_option = page.all(combobox.option_selector).last
    chosen = deep_option.text
    deep_option.click
    expect(page).to have_no_css(combobox.in_panel("[role='listbox']"))

    combobox.open
    expect(page).to have_css(combobox.option_selector, wait: 20)

    # Both halves matter. The offset proves the list moved rather than opening at row one, and
    # the mounted row proves it moved to the right place: a windowed list can be scrolled far
    # from the top and still have failed to reach the selection.
    expect(combobox.list_scroll_top).to be > 0
    expect(page).to have_css("#{combobox.option_selector}[aria-selected='true']", text: chosen)
  end

  # The short-list half of the same complaint, and a different mechanism: every row is mounted
  # here, so the cursor CAN see the selection — the list simply opened at the top with it out of
  # view. Fifteen locales against a viewport of roughly nine, so a selection near the end is off
  # screen without any windowing being involved.
  it "opens scrolled to the selection when every row is mounted" do
    visit "/styleguide/molecules/select?group=appearance"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-icon")

    # A static trigger, so the option is clicked straight out of the list rather than filtered
    # for: there is no query input to type into.
    combobox.open_trigger
    expect(page).to have_css(combobox.option_selector, wait: 10)
    find(combobox.option_selector, text: "Türkçe").click
    expect(page).to have_no_css(combobox.in_panel("[role='listbox']"))

    combobox.open_trigger
    expect(page).to have_css(combobox.option_selector, wait: 10)
    expect(combobox.list_scroll_top).to be > 0
  end

  # The counterpart that keeps the reveal honest: with nothing held there is no selection to
  # reveal, so the list must still open at the top rather than somewhere arbitrary.
  it "opens at the top when nothing is selected" do
    visit "/styleguide/molecules/select?group=limits"
    combobox = PageObjects::Components::UiKit::DSelect.by_identifier("sg-large-list")

    combobox.open
    expect(page).to have_css(combobox.option_selector, wait: 20)
    expect(combobox.list_scroll_top).to eq(0)
  end
end
