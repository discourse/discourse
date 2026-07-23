# frozen_string_literal: true

# Real-browser coverage for the core ui-kit `DSelect` windowed reveal.
#
# The rendering tests drive reveal by calling the engine directly; what they structurally
# cannot prove is the thing the feature rests on: scrolling the windowed listbox to its end
# band loads the next chunk. Only a real browser, with a real scroll container and the real
# windowing engine, exercises that path.
#
# The list is windowed, so counting mounted `[role=option]` elements measures the window,
# not how many rows have loaded. The loaded extent is the highest absolute `data-index`
# reachable by scrolling to the bottom — that is what these assertions read.
#
# It lives in the styleguide plugin because the styleguide's large-list example is the only
# rendered `DSelect` with more options than the render cap. Move it to a core `spec/system`
# once a real core consumer renders a list that large.
describe "UiKit | DSelect windowed reveal" do
  fab!(:admin)

  # The styleguide's large-list example: 5000 client options, capped at 200 rendered.
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

  it "loads the next chunk when the user scrolls the window to its end" do
    combobox.open
    first_extent = combobox.reveal_to_index(49)
    expect(first_extent).to be >= 49

    # Scrolling to the end band trips the reveal: the reachable extent grows past the first
    # chunk. This is the assertion no qunit test can make — a real scroll driving the engine.
    expect(combobox.reveal_to_index(99)).to be >= 99
  end

  it "stops at the render cap and asks the user to keep filtering" do
    combobox.open

    expect(combobox.reveal_to_index(199)).to eq(199)
    expect(combobox.narrow_hint?).to eq(true)
  end

  it "starts a fresh window when the query changes" do
    combobox.open
    expect(combobox.reveal_to_index(199)).to eq(199)

    combobox.input.send_keys("Option 1")

    # "Option 1" still matches far more than the cap, but a new query restarts from the first
    # chunk rather than inheriting the capped window — so the list is no longer pinned.
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
