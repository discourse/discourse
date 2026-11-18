# frozen_string_literal: true
describe "Editing topic timers" do
  fab!(:admin)
  fab!(:post)
  fab!(:topic) { post.topic }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:timer_type_selector) { PageObjects::Components::DNativeSelect.new(".timer-type") }

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

  it "hides the reopen action as soon as a restricted category moderator closes a topic" do
    SiteSetting.enable_category_group_moderation = true
    SiteSetting.category_group_moderators_can_reopen_topics = false
    category_moderation = Fabricate(:category_moderation_group)
    category_moderator = Fabricate(:user)
    category_moderation.group.add(category_moderator)
    topic.update!(category: category_moderation.category)
    sign_in(category_moderator)
    topic_page.visit_topic(topic)

    topic_page.click_admin_menu_button
    find(".topic-admin-close button").click
    topic_page.click_admin_menu_button

    expect(page).to have_css(".topic-admin-archive")
    expect(page).to have_no_css(".topic-admin-open")
    expect(topic.reload).to be_closed
  end
end
