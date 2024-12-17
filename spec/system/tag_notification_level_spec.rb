# frozen_string_literal: true

describe "Tag notification level", type: :system do
  let(:tags_page) { PageObjects::Pages::Tag.new }
  let(:notifications_tracking) do
    PageObjects::Components::NotificationsTracking.new(".tag-notifications-tracking")
  end

  fab!(:tag_1) { Fabricate(:tag) }
  fab!(:current_user) { Fabricate(:admin) }

  before { sign_in(current_user) }

  describe "when changing a tag's notification level" do
    it "should change instantly" do
      tags_page.visit_tag(tag_1)

      expect(notifications_tracking).to have_selected_level_name("regular")

      notifications_tracking.toggle
      notifications_tracking.select_level_name("watching")

      expect(notifications_tracking).to have_selected_level_name("watching")
    end
  end
end
