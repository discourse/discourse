# frozen_string_literal: true

# Deleting a character must re-query, and the rendered rows must belong to the query currently
# in the input.
#
# This lives in a system spec deliberately. Under QUnit `discourseDebounce` rewrites its delay
# to 10ms and every `await` drains the runloop, so two loads can never overlap and the race is
# unreachable — four rendering tests pass against the reported bug. A real browser keeps the
# real debounce and the styleguide's deliberately slow (900ms) paged source, which is what lets
# a shortened query overlap the request it supersedes.
#
# Two constraints shape every assertion here:
#
# - Never count rows. The listbox is windowed by `DVirtualList`, so counting mounted
#   `[role='option']` elements measures the window (~19 rows for anything long) and reads the
#   same for two entirely different result sets.
# - Only name rows near the top of the result set. Rows below the window are not mounted, so a
#   correct list would still fail an assertion naming one.
describe "UiKit | DSelect refiltering" do
  fab!(:admin)

  let(:combobox) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-paged") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=data"
    expect(page).to have_css("[data-identifier='sg-paged'][data-trigger]")
  end

  # Topic titles end in "#<id>" over 1..5000, and the prose carries no digits, so a numeric query
  # is a substring match on the id and each shortening widens the set. The regexes are
  # end-anchored because "#12" is also a prefix of "#1234" — an unanchored match would not
  # discriminate at all.
  #
  # Each step names a row the *previous* query could not match, which lands at index 0 or 1 of
  # the widened set (ids ascending) and so is always inside the window.
  STEPS = [
    ["123", /#1123$/], # 1123 contains "123" but not "1234"; index 1
    ["12", /#12$/], # 12 contains "12" but not "123";      index 0
    ["1", /#1$/], # 1 contains "1" but not "12";         index 0
  ]

  def settle_on_long_query
    combobox.open
    combobox.input.send_keys("1234")

    # The source is slow on purpose; wait for it to settle on the long query before deleting.
    # The count pins it: every wider, earlier result set has more than one row.
    expect(page).to have_css(combobox.option_selector, text: /#1234$/, count: 1, wait: 20)
  end

  it "shows rows for the shortened query after a backspace" do
    settle_on_long_query

    value, newly_matching = STEPS.first
    combobox.input.send_keys(:backspace)
    expect(combobox.input.value).to eq(value)

    expect(page).to have_css(combobox.option_selector, text: newly_matching, wait: 20)
  end

  it "stays consistent across several backspaces" do
    settle_on_long_query

    STEPS.each do |value, newly_matching|
      combobox.input.send_keys(:backspace)
      expect(combobox.input.value).to eq(value)
      expect(page).to have_css(combobox.option_selector, text: newly_matching, wait: 20)
    end
  end
end
