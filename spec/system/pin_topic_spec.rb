# frozen_string_literal: true

describe "Pinning a topic" do
  fab!(:admin)
  fab!(:topic)
  fab!(:post) { Fabricate(:post, topic:) }

  let(:topic_page) { PageObjects::Pages::Topic.new }
  let(:topic_admin_menu) { PageObjects::Components::TopicAdminMenu.new }
  let(:feature_topic_modal) { PageObjects::Modals::FeatureTopic.new }

  before { sign_in(admin) }

  it "lets an admin edit a custom pin time without losing focus",
     time: "2026-10-23 12:00 UTC",
     timezone: "UTC" do
    [false, true].each do |globally|
      topic_page.visit_topic(topic)
      topic_page.click_admin_menu_button
      topic_admin_menu.click_pin_topic

      feature_topic_modal.select_custom_date(day: 28, globally:)
      feature_topic_modal.set_time(time: "14:35", globally:)

      expect(feature_topic_modal).to have_focused_time(time: "14:35", globally:)

      feature_topic_modal.pin(globally:)
      expect(feature_topic_modal).to be_closed

      page.refresh
      topic_page.click_admin_menu_button
      topic_admin_menu.click_pin_topic

      expect(feature_topic_modal).to have_pin_expiry("October 28, 2026")
      expect(topic.reload.pinned_until).to eq_time(Time.utc(2026, 10, 28, 14, 35))

      feature_topic_modal.unpin
      expect(feature_topic_modal).to be_closed
    end
  end
end
