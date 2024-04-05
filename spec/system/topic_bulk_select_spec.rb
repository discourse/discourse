# frozen_string_literal: true

describe "Topic bulk select", type: :system do
  before { SiteSetting.experimental_topic_bulk_actions_enabled_groups = "1" }
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  context "when in topic" do
    fab!(:admin)
    fab!(:user)

    it "closes multiple topics" do
      sign_in(admin)
      visit("/latest")
      expect(page).to have_css(".topic-list button.bulk-select")
      expect(topic_list_header).to have_bulk_select_button

      # Click bulk select button
      topic_list_header.click_bulk_select_button
      expect(topic_list).to have_topic_checkbox(topics.first)

      # Select Topics
      topic_list.click_topic_checkbox(topics.first)
      topic_list.click_topic_checkbox(topics.second)

      # Has Dropdown
      expect(topic_list_header).to have_bulk_select_topics_dropdown
      topic_list_header.click_bulk_select_topics_dropdown

      # Clicking the close button opens up the modal
      expect(topic_list_header).to have_close_topics_button
      topic_list_header.click_close_topics_button
      expect(topic_list_header).to have_bulk_select_modal

      # Closes the selected topics
      topic_list_header.click_bulk_topics_confirm
      expect(topic_list).to have_closed_status(topics.first)
    end

    it "closes topics normally" do
      # Watch the topic as a user
      sign_in(user)
      visit("/latest")
      topic = topics.third
      visit("/t/#{topic.slug}/#{topic.id}")
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Bulk close the topic as an admin
      sign_in(admin)
      visit("/latest")
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topics.third)
      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_close_topics_button
      topic_list_header.click_bulk_topics_confirm

      # Check that the user did receive a new post notification badge
      sign_in(user)
      visit("/latest")
      expect(topic_list).to have_unread_badge(topics.third)
    end

    it "closes topics silently" do
      # Watch the topic as a user
      sign_in(user)
      visit("/latest")
      topic = topics.first
      visit("/t/#{topic.slug}/#{topic.id}")
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)

      # Bulk close the topic as an admin
      sign_in(admin)
      visit("/latest")
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topics.first)
      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_close_topics_button
      topic_list_header.click_silent # Check Silent
      topic_list_header.click_bulk_topics_confirm

      # Check that the user didn't receive a new post notification badge
      sign_in(user)
      visit("/latest")
      expect(topic_list).to have_no_unread_badge(topics.first)
    end

    it "closes topics with message" do
      # Bulk close the topic with a message
      sign_in(admin)
      visit("/latest")
      topic = topics.first
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topics.first)
      topic_list_header.click_bulk_select_topics_dropdown
      topic_list_header.click_close_topics_button

      # Fill in message
      topic_list_header.fill_in_close_note("My message")
      sleep(10)
      topic_list_header.click_bulk_topics_confirm

      # Check that the topic now has the message
      visit("/t/#{topic.slug}/#{topic.id}")
      expect(topic_page).to have_content("My message")
      sleep(10)
    end

    it "works with keyboard shortcuts" do
      sign_in(admin)
      visit("/latest")

      send_keys([:shift, "b"])
      send_keys("j")
      send_keys("x") # toggle select
      expect(topic_list).to have_checkbox_selected_on_row(1)

      send_keys("x") # toggle deselect
      expect(topic_list).to have_no_checkbox_selected_on_row(1)

      # watch topic and add a reply so we have something in /unread
      topic = topics.first
      visit("/t/#{topic.slug}/#{topic.id}")
      topic_page.watch_topic
      expect(topic_page).to have_read_post(1)
      Fabricate(:post, topic: topic)

      visit("/unread")
      expect(topic_list).to have_topics

      send_keys([:shift, "b"])
      send_keys("j")
      send_keys("x")
      send_keys([:shift, "d"])

      topic_list_header.click_dismiss_read_confirm

      expect(topic_list).to have_no_topics
    end
  end
end
