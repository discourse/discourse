# frozen_string_literal: true

RSpec.describe "Filter new topics" do
  include ThemeScreenshotMarker

  fab!(:user)
  fab!(:category) { Fabricate(:category, name: "Announcements") }
  fab!(:new_topic) do
    Fabricate(:topic, category: category, title: "What is coming next for our community")
  end
  fab!(:unread_topic) do
    Fabricate(:topic, category: category, title: "Share your feedback on the latest release")
  end
  fab!(:closed_topic) { Fabricate(:topic, category: category, closed: true) }
  let(:navigation) { PageObjects::Components::FilterNewNavigation.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:query_filter) { PageObjects::Components::TopicQueryFilter.new }

  before do
    Fabricate(:post, topic: new_topic)
    Fabricate(:post, topic: unread_topic)
    Fabricate(:post, topic: unread_topic)
    Fabricate(:post, topic: closed_topic)
    TopicUser.change(
      user.id,
      unread_topic.id,
      last_read_post_number: 1,
      notification_level: TopicUser.notification_levels[:tracking],
    )
    user.user_option.update!(new_topic_duration_minutes: User::NewTopicDuration::ALWAYS)
    sign_in(user)
  end

  it "lets the user switch between all matches, new topics, and unread replies" do
    query = "category:#{category.slug} status:open"
    SiteSetting.enable_unified_new = false
    visit("/filter?q=#{CGI.escape(query)}")
    expect(navigation).to have_no_navigation
    expect(topic_list).to have_topic(new_topic)
    screenshot_marker(label: "filter-unified-new-before")

    SiteSetting.enable_unified_new = true
    page.refresh
    navigation.select_view("new")
    expect(navigation).to have_counts(topics: 1, replies: 1)
    expect(topic_list).to have_topic(new_topic)
    expect(topic_list).to have_topic(unread_topic)
    expect(topic_list).to have_no_topic(closed_topic)
    screenshot_marker(label: "filter-unified-new-after")

    navigation.select_subset("topics")
    expect(query_filter).to have_input_text("#{query} in:new-topics")
    expect(topic_list).to have_topic(new_topic)
    expect(topic_list).to have_no_topic(unread_topic)

    navigation.select_subset("replies")
    expect(query_filter).to have_input_text("#{query} in:new-replies")
    expect(topic_list).to have_topic(unread_topic)
    expect(topic_list).to have_no_topic(new_topic)

    page.go_back
    expect(query_filter).to have_input_text("#{query} in:new-topics")
    expect(topic_list).to have_topic(new_topic)
    expect(topic_list).to have_no_topic(unread_topic)

    page.go_forward
    expect(query_filter).to have_input_text("#{query} in:new-replies")
    page.refresh
    expect(query_filter).to have_input_text("#{query} in:new-replies")
    expect(topic_list).to have_topic(unread_topic)
    expect(topic_list).to have_no_topic(new_topic)

    navigation.select_view("all")
    expect(query_filter).to have_input_text(query)
    expect(topic_list).to have_topic(new_topic)
    expect(topic_list).to have_topic(unread_topic)
  end
end
