# frozen_string_literal: true

RSpec.describe "DSelect sticky action" do
  include ThemeScreenshotMarker

  fab!(:admin)

  let(:sticky_select) { PageObjects::Components::StickySelectExample.new }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=content"
  end

  it "lets the user suggest a topic from the bottom of the list" do
    sticky_select.open_trigger
    first_topic = sticky_select.first_topic_label
    sticky_select.scroll_listbox_to_bottom

    expect(sticky_select).to have_visible_suggestion
    expect(sticky_select).to have_opaque_suggestion
    screenshot_marker(label: "dselect-sticky-action")

    sticky_select.choose_suggestion
    expect(sticky_select).to have_no_listbox
    expect(sticky_select).to have_selected_topic(first_topic)
  end
end
