# frozen_string_literal: true

RSpec.describe "Nested activity log" do
  fab!(:admin)
  fab!(:topic) { Fabricate(:topic, user: admin) }
  fab!(:op) { Fabricate(:post, topic: topic, user: admin, post_number: 1) }

  let(:activity_log) { PageObjects::Components::NestedActivityLog.new }
  let(:composer) { PageObjects::Components::Composer.new }
  let(:dialog) { PageObjects::Components::Dialog.new }
  let(:nested_view) { PageObjects::Pages::NestedView.new }

  before do
    SiteSetting.nested_replies_enabled = true
    Fabricate(:nested_topic, topic: topic)
    sign_in(admin)
  end

  it "opens the activity log modal and lists small actions" do
    topic.add_small_action(admin, "closed.enabled")

    nested_view.visit_nested(topic).open_activity_log

    expect(activity_log).to be_open
    expect(activity_log).to have_item_count(2)
  end

  it "hides the activity log link on a topic with no small actions" do
    nested_view.visit_nested(topic)

    expect(page).to have_css(".nested-view__controls")
    expect(nested_view).to have_no_activity_log_link
  end

  it "edits, deletes, and recovers a small action" do
    action =
      Fabricate(
        :small_action,
        topic: topic,
        user: admin,
        action_code: "closed.enabled",
        raw: "Original activity details",
      )

    nested_view.visit_nested(topic).open_activity_log
    expect(activity_log).to have_item_text(action, "Original activity details")
    expect(activity_log).to have_edit_button(action)
    expect(activity_log).to have_delete_button(action)

    activity_log.click_edit(action)
    expect(activity_log).to be_closed
    expect(composer).to be_opened

    composer.fill_content("Updated activity details")
    composer.submit
    expect(composer).to be_closed

    nested_view.open_activity_log
    expect(activity_log).to have_item_text(action, "Updated activity details")

    activity_log.click_delete(action)
    dialog.click_yes
    expect(activity_log).to have_recover_button(action)
    expect(activity_log).to have_no_edit_button(action)

    activity_log.click_recover(action)
    expect(activity_log).to have_item_text(action, "Updated activity details")
    expect(activity_log).to have_edit_button(action)
    expect(activity_log).to have_delete_button(action)
  end
end
