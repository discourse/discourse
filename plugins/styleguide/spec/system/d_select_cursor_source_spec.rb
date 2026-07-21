# frozen_string_literal: true

# Real-browser coverage for a source that reports `hasMore` but no `total`.
#
# The rendering tests drive reveal by calling the engine directly with hand-built pages, so
# they prove the set size flips from -1 to the real count but say nothing about whether a
# deployed source can actually reach that state. That depends on the source's page size
# against the render cap: the styleguide example pages 50 at a time over 5000 options, so
# scrolling hits the cap long before completeness, and only filtering narrows the set enough
# for the source to exhaust. This spec pins the path a user can actually take.
describe "UiKit | DSelect cursor source" do
  fab!(:admin)

  let(:combobox) do
    PageObjects::Components::UiKit::DSelect.new(
      ".select-examples__paged-cursor .d-combobox__trigger",
    )
  end

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select"
    expect(page).to have_css(".select-examples__paged-cursor .d-combobox__trigger")
  end

  it "reports an unknown set size while pages remain, and the real count once complete" do
    combobox.open

    expect(page).to have_css("[role='listbox'] [role='option']", count: 50, wait: 10)
    expect(combobox.options.first[:"aria-setsize"]).to eq("-1")
    expect(combobox.sentinel?).to eq(true)

    # Narrow enough that the source exhausts within a single page and declares completeness.
    combobox.input.send_keys("Option 4242")

    expect(page).to have_css("[role='listbox'] [role='option']", count: 1, wait: 10)
    expect(combobox.options.first[:"aria-setsize"]).to eq("1")
    expect(combobox.sentinel?).to eq(false)
  end
end
