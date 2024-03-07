# frozen_string_literal: true

describe "Silence Close Notification", type: :system do
  before { SiteSetting.experimental_topic_bulk_actions_enabled_groups = "1" }
  fab!(:topics) { Fabricate.times(10, :post).map(&:topic) }
  let(:topic_list) { PageObjects::Components::TopicList.new }
  let(:topic_page) { PageObjects::Pages::Topic.new }

  context "when closing a topic" do
    fab!(:admin)
    fab!(:user)

    it "silences the close notification when enabled" do
      sign_in(user)
      visit("/u/#{user.username}/preferences/notifications")
    end
  end
end
