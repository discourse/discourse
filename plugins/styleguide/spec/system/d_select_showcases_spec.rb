# frozen_string_literal: true

RSpec.describe "DSelect showcases" do
  fab!(:admin)

  let(:showcases) { PageObjects::Components::SelectExamples.new }

  before do
    SiteSetting.styleguide_enabled = true
    sign_in(admin)
    visit "/styleguide/molecules/select?group=pickers"
  end

  it "lets the user exercise rich, asynchronous, and action-oriented selects" do
    expect(showcases).to have_resolved_reviewers(count: 7)
    expect(showcases.reviewer_chips_wrapped?).to eq(true)

    showcases.open_reviewers
    expect(showcases).to have_disabled_reviewer("Taylor Kim")

    # Dismiss before moving on. Leaving this panel open and clicking straight into the next
    # picker is something a reader cannot do either — the first click would only dismiss the
    # open panel — and it silently depends on the two cards sitting far enough apart that the
    # open panel never covers the next trigger.
    showcases.close_open_panel
    expect(showcases).to have_no_open_panel

    showcases.create_tag("architecture")
    expect(showcases).to have_selected_tag("architecture")
    expect(showcases.tag_picker_expanded?).to eq(true)

    showcases.close_tag_picker
    expect(showcases).to have_notification_selection("Watching")
    showcases.open_notifications
    expect(showcases).to have_notification_icons
    showcases.close_open_panel
    showcases.use_notification_action
    expect(showcases).to have_notification_selection("Watching")
    expect(showcases).to have_notification_action_count(1)
  end
end
