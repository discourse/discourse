# frozen_string_literal: true

describe "Closing a topic" do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  fab!(:admin)
  fab!(:user)

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  it "does not mark the topic unread" do
    sign_in(user)
    topic = topics.third
    topic_page.visit_topic(topic)
    topic_page.watch_topic
    expect(topic_page).to have_read_post(1)

    TopicStatusUpdater.new(topic, admin).update!("closed", true)

    # The close action is a small action, which no longer marks a topic unread.
    visit("/latest")
    expect(topic_list).to have_no_unread_badge(topics.third)
  end
end
