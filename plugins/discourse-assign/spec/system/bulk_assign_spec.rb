# frozen_string_literal: true

describe "Assign | Bulk Assign" do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }
  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  fab!(:staff_user) { Fabricate(:user, groups: [Group[:staff]]) }
  fab!(:admin)
  fab!(:assignable_group) { Fabricate(:group, assignable_level: Group::ALIAS_LEVELS[:everyone]) }
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }

  before do
    SiteSetting.assign_enabled = true

    admin.update!(last_seen_at: 1.day.ago)
    sign_in(admin)
  end

  describe "from topic list" do
    it "can assign and unassign topics" do
      ## Assign
      visit "/latest"
      topic = topics.first

      # Select Topic
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)

      # Click Assign Button
      topic_list_header.click_bulk_select_topics_dropdown
      expect(topic_list_header).to have_assign_topics_button
      topic_list_header.click_assign_topics_button
      expect(topic_list_header).to have_bulk_select_modal

      # Assign User
      assign_modal.assignee = staff_user

      # Click Confirm
      topic_list_header.click_bulk_topics_confirm
      expect(assign_modal).to be_closed

      # Reload and check that topic is now assigned
      visit "/latest"
      expect(topic_list).to have_assigned_status(topic)

      ## Unassign

      # Select Topic
      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)

      # Click Unassign Button
      topic_list_header.click_bulk_select_topics_dropdown
      expect(topic_list_header).to have_unassign_topics_button
      topic_list_header.click_unassign_topics_button
      expect(topic_list_header).to have_bulk_select_modal

      # Click Confirm
      topic_list_header.click_bulk_topics_confirm
      expect(assign_modal).to be_closed

      # Reload and check that topic is now assigned
      visit "/latest"
      expect(topic_list).to have_unassigned_status(topic)
    end

    it "can assign topics to a group" do
      visit "/latest"
      topic = topics.first

      topic_list_header.click_bulk_select_button
      topic_list.click_topic_checkbox(topic)

      topic_list_header.click_bulk_select_topics_dropdown
      expect(topic_list_header).to have_assign_topics_button
      topic_list_header.click_assign_topics_button
      expect(topic_list_header).to have_bulk_select_modal

      assign_modal.assignee = assignable_group

      topic_list_header.click_bulk_topics_confirm

      expect(assign_modal).to be_closed

      visit "/latest"
      expect(topic_list).to have_assigned_status(topic)
    end
  end
end
