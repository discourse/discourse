# frozen_string_literal: true

RSpec.describe "Assign | Group assigned", type: :system, js: true do
  fab!(:admin)
  fab!(:group)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic: topic) }

  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_list_header) { PageObjects::Components::TopicListHeader.new }
  let(:topic_bulk_modal) { PageObjects::Modals::TopicBulkActions.new }
  let(:assign_modal) { PageObjects::Modals::Assign.new }

  before do
    group.add(admin)
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = group.id.to_s
    Assigner.new(topic, Discourse.system_user).assign(admin)
    sign_in(admin)
  end

  it "allows to bulk select assigned topics" do
    visit "/g/#{group.name}/assigned/everyone"

    topic_list_header.click_bulk_select_button
    topic_list.click_topic_checkbox(topic)

    # Click Assign Button
    topic_list_header.click_bulk_select_topics_dropdown
    expect(topic_list_header).to have_assign_topics_button
    topic_list_header.click_assign_topics_button
    expect(topic_list_header).to have_bulk_select_modal

    # Assign User
    assignee = admin.username
    select_kit = PageObjects::Components::SelectKit.new("#assignee-chooser")

    # This initial collapse is needed because for some reason the modal is
    # opening with `is-expanded` property, but it isn't actually expanded.
    select_kit.collapse

    select_kit.search(assignee)
    select_kit.select_row_by_value(assignee)
    select_kit.collapse

    # Click Confirm
    topic_list_header.click_bulk_topics_confirm

    expect(topic_bulk_modal).to be_closed
    expect(Assignment.find_by(topic: topic).assigned_to).to eq(admin)
  end
end
