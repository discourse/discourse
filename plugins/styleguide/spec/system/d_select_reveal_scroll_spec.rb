# frozen_string_literal: true

# Fetching another page for the SAME query appends rows; it must never move the viewport. The
# scroll reset belongs to a *new* query, and a reveal is triggered by scrolling to the bottom —
# so resetting there throws the reader back to row one at the exact moment they asked for more.
describe "UiKit | DSelect reveal scrolling" do
  fab!(:admin)

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=data"
  end

  # Both paginated examples, because they differ in how the source describes what remains
  # (a total versus bare more-ness) and that drives separate engine paths.
  %w[sg-paged sg-paged-cursor].each do |identifier|
    it "keeps the viewport in place when #{identifier} reveals another page" do
      combobox = PageObjects::Components::UiKit::DSelect.by_identifier(identifier)
      combobox.open
      expect(page).to have_css(combobox.option_selector, wait: 20)

      combobox.scroll_listbox_to_bottom
      expect(combobox.list_scroll_top).to be > 0

      # Sampled across the whole fetch rather than checked once at the end: the reset lands the
      # moment the page is appended, and a single late read could miss it if anything scrolled
      # back afterwards. The source takes ~900ms, so this spans it comfortably.
      offsets = []
      20.times do
        sleep 0.15
        offsets << combobox.list_scroll_top
      end

      expect(offsets).to all(be > 0),
      "the viewport jumped to the top while revealing: #{offsets.inspect}"
    end
  end
end
