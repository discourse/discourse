# frozen_string_literal: true

describe "Assign | Bulk Assign", type: :system do
  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }
  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  fab!(:staff_user) { Fabricate(:user, groups: [Group[:staff]]) }
  fab!(:admin)
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }

  before do
    SiteSetting.assign_enabled = true

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
      assignee = staff_user.username
      select_kit = PageObjects::Components::SelectKit.new("#assignee-chooser")

      # This initial collapse is needed because for some reason the modal is
      # opening with `is-expanded` property, but it isn't actually expanded.
      select_kit.collapse

      select_kit.search(assignee)
      select_kit.select_row_by_value(assignee)
      select_kit.collapse

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
  end
end
