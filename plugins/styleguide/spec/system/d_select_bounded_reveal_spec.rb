# frozen_string_literal: true

# Real-browser coverage for the core ui-kit `DSelect` windowed client list.
#
# A large client list is now rendered in full and windowed by `DVirtualList`: only a slice
# is mounted, and scrolling the window mounts deeper rows. What the rendering tests cannot
# prove is that a real scroll container, over the real windowing engine, reaches the true
# tail of a huge list — with no render cap and no keep-filtering hint.
#
# The list is windowed, so counting mounted `[role=option]` elements measures the window,
# not the list. The extent reached is the highest absolute `data-index` mounted after
# scrolling to the bottom — that is what these assertions read.
#
# It lives in the styleguide plugin because the styleguide's large-list example is the only
# rendered `DSelect` with more options than a single window. Move it to a core `spec/system`
# once a real core consumer renders a list that large.
describe "UiKit | DSelect windowed client list" do
  fab!(:admin)

  # The styleguide's large-list example: 5000 client options, windowed by DVirtualList.
  let(:combobox) do
    PageObjects::Components::UiKit::DSelect.new(".select-examples__large-list .d-combobox__trigger")
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
    expect(page).to have_css(".select-examples__large-list .d-combobox__trigger")
  end

  it "opens onto a bounded window of a huge list, sized to the honest total" do
    combobox.open

    # The window is a small slice near the top, nowhere near the 5000th row.
    expect(page).to have_css("[role='listbox'] [role='option']")
    expect(combobox.max_loaded_index).to be < 50
    # The set size a screen reader hears is the real total, not the rendered window.
    expect(combobox.options.first[:"aria-setsize"]).to eq("5000")
    expect(combobox.narrow_hint?).to eq(false)
  end

  it "mounts deeper rows as the window scrolls toward the end" do
    combobox.open
    first_extent = combobox.reveal_to_index(49)
    expect(first_extent).to be >= 49

    # Scrolling the window mounts rows further down the list — the assertion no qunit test can
    # make, a real scroll container over the real windowing engine.
    expect(combobox.reveal_to_index(99)).to be >= 99
  end

  it "scrolls the whole huge list into reach with no cap and no narrow hint" do
    combobox.open

    # The retired 200-row cap no longer bounds a client list: scrolling reaches its true last
    # row (index 4999 of a 5000-option list), and no keep-filtering hint ever appears.
    expect(combobox.reveal_to_index(4999)).to eq(4999)
    expect(combobox.narrow_hint?).to eq(false)
  end

  it "returns to the top of the window when the query changes" do
    combobox.open
    expect(combobox.reveal_to_index(999)).to be >= 999

    combobox.input.send_keys("Option 1")

    # A new query restarts the window at the top rather than holding the scrolled position,
    # and a client list is never pinned at a cap.
    expect(combobox.max_loaded_index).to be < 50
    expect(combobox.narrow_hint?).to eq(false)
  end

  it "keeps scrolling inside the listbox rather than moving the page" do
    combobox.open
    page_offset = page.evaluate_script("window.scrollY")

    expect(combobox.reveal_to_index(99)).to be >= 99

    expect(page.evaluate_script("window.scrollY")).to eq(page_offset)
    expect(page.evaluate_script("document.querySelector('.d-virtual-list').scrollTop")).to be > 0
  end
end
