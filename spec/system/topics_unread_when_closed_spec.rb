# frozen_string_literal: true

describe "Topics unread when closed", type: :system do
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  context "when closing a topic" do
    fab!(:admin)
    fab!(:user)

    it "close notifications do not appear when disabled" do
      user.user_option.update!(topics_unread_when_closed: false)
      sign_in(user)
      topic = topics.third
      topic_page.visit_topic(topic)
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Close the topic as an admin
      TopicStatusUpdater.new(topic, admin).update!("closed", true)

      # Check that the user did not receive a new post notification badge
      visit("/latest")
      expect(topic_list).to have_no_unread_badge(topics.third)
    end

    it "close notifications appear when enabled (the default)" do
      user.user_option.update!(topics_unread_when_closed: true)
      sign_in(user)
      topic = topics.third
      topic_page.visit_topic(topic)
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Close the topic as an admin
      TopicStatusUpdater.new(topic, admin).update!("closed", true)

      # Check that the user did receive a new post notification badge
      visit("/latest")
      expect(topic_list).to have_unread_badge(topics.third)
    end
  end
end
