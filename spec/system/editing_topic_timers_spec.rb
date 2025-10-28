# frozen_string_literal: true
describe "Editing topic timers", type: :system do
  fab!(:admin)
  fab!(:post)
  fab!(:topic) { post.topic }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:timer_type_selector) { PageObjects::Components::DSelect.new(".timer-type") }

  before { sign_in(admin) }

  it "allows a user to update a topic timer from auto close after last post to auto close topic" do
    topic_timer =
      Fabricate(:topic_timer_close_based_on_last_post, topic:, user: admin, duration_minutes: 20)

    topic_page.visit_topic(topic_timer.topic)
    topic_admin_menu = topic_page.click_admin_menu_button
    edit_topic_timer_modal = topic_admin_menu.click_set_topic_timer

    edit_topic_timer_modal.select_timer_type("close")
    edit_topic_timer_modal.set_relative_time_duration("10")
    edit_topic_timer_modal.set_relative_time_interval("hours")
    edit_topic_timer_modal.click_save

    expect(page).to have_text("This topic will automatically close in 10 hours.")
  end
end
