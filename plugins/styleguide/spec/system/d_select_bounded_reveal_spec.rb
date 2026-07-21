# frozen_string_literal: true

# Real-browser coverage for the core ui-kit `DSelect` bounded reveal.
#
# IntersectionObserver does not fire reliably under qunit, so the rendering tests
# (d-select-reveal-test.gjs) drive reveal by calling the engine directly. That leaves one
# thing they structurally cannot prove, and it is the thing the feature rests on: scrolling
# the listbox trips the sentinel and the next chunk appears.
#
# It lives in the styleguide plugin because the styleguide's large-list example is the only
# rendered `DSelect` with more options than the render cap. Move it to a core `spec/system`
# once a real core consumer renders a list that large.
describe "UiKit | DSelect bounded reveal" do
  fab!(:admin)

  # The styleguide's large-list example: 5000 client options.
  let(:combobox) do
    PageObjects::Components::UiKit::DSelect.new(".select-examples__large-list .d-combobox__trigger")
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
    expect(page).to have_css(".select-examples__large-list .d-combobox__trigger")
  end

  it "renders only the first chunk of a huge list" do
    combobox.open

    expect(combobox.option_count).to eq(50)
    # The set size is the honest total, not the rendered window.
    expect(combobox.options.first[:"aria-setsize"]).to eq("5000")
    expect(combobox.sentinel?).to eq(true)
    expect(combobox.narrow_hint?).to eq(false)
  end

  it "reveals the next chunk when the listbox is scrolled" do
    combobox.open
    expect(combobox.option_count).to eq(50)

    combobox.scroll_listbox_to_bottom

    # This is the assertion no qunit test can make: a real observer, rooted at the real
    # scroll container, firing on a real scroll.
    expect(page).to have_css("[role='listbox'] [role='option']", count: 100)
  end

  it "stops at the hard cap and asks the user to keep filtering" do
    combobox.open

    expect(combobox.reveal_until(200)).to eq(200)
    expect(combobox.sentinel?).to eq(false)
    expect(combobox.narrow_hint?).to eq(true)
  end

  it "resets the window when the query changes" do
    combobox.open
    expect(combobox.reveal_until(200)).to eq(200)

    combobox.input.send_keys("Option 1")

    # "Option 1" still matches far more than the cap, but a new query starts from the first
    # chunk again rather than inheriting the old window — so the list is no longer pinned.
    expect(page).to have_css("[role='listbox'] [role='option']", count: 50)
    expect(combobox.narrow_hint?).to eq(false)
    expect(combobox.sentinel?).to eq(true)
  end

  it "keeps scrolling inside the listbox rather than moving the page" do
    combobox.open
    page_offset = page.evaluate_script("window.scrollY")

    combobox.scroll_listbox_to_bottom
    expect(page).to have_css("[role='listbox'] [role='option']", count: 100)

    expect(page.evaluate_script("window.scrollY")).to eq(page_offset)
    expect(page.evaluate_script("document.querySelector(\"[role='listbox']\").scrollTop")).to be > 0
  end
end
