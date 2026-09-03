# frozen_string_literal: true

# Real-browser coverage for a source that reports `hasMore` but no `total`.
#
# The rendering tests drive reveal by calling the engine directly with hand-built pages, so
# they prove the set is sized by the loaded rows and settles on the real count, but say
# nothing about whether a deployed source can actually reach that state. That depends on the
# source's page size against the render cap: the styleguide example pages 50 at a time over
# 5000 options, so scrolling hits the cap long before completeness, and only filtering
# narrows the set enough for the source to exhaust. This spec pins the path a user can
# actually take.
describe "UiKit | DSelect cursor source" do
  fab!(:admin)

  let(:combobox) { PageObjects::Components::UiKit::DSelect.by_identifier("sg-paged-cursor") }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=data"
    expect(page).to have_css("[data-identifier='sg-paged-cursor'][data-trigger]")
  end

  it "sizes the set by the loaded rows while paging, and by the real count once complete" do
    combobox.open

    # A cursor source still paging is sized by what it has loaded — the rows a reader can
    # actually reach — never by the -1 sentinel, which assistive tech renders unusably.
    # One page of 50 has landed, so every mounted option reports a set of 50.
    expect(page).to have_css(combobox.option_selector, wait: 10)
    expect(combobox.options.first[:"aria-setsize"]).to eq("50")

    # Narrow enough that the source exhausts within a single page and declares completeness.
    # Every topic title ends in a unique "#<id>", so this matches exactly one row.
    combobox.input.send_keys("#4242")

    expect(page).to have_css(combobox.option_selector, count: 1, wait: 10)
    expect(combobox.options.first[:"aria-setsize"]).to eq("1")
  end
end
