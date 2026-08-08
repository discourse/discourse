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
    #
    # Asserted as one waiting matcher that names the attribute, rather than waiting for any row and
    # then reading `.options.first`. That two-step is a check-then-fetch race: the row satisfying the
    # wait and the row re-queried afterwards need not be the same one, because the virtualizer can
    # swap the mounted window in between — which is how this spec came to fail once with the right
    # markup on screen. Waiting for a row that ALREADY carries the value cannot sample too early,
    # and unlike a retry it does not paper over the race it is meant to observe.
    expect(page).to have_css("#{combobox.option_selector}[aria-setsize='50']", wait: 10)

    # Narrow enough that the source exhausts within a single page and declares completeness.
    # Every topic title ends in a unique "#<id>", so this matches exactly one row.
    combobox.input.send_keys("#4242")

    expect(page).to have_css("#{combobox.option_selector}[aria-setsize='1']", count: 1, wait: 10)
  end
end
