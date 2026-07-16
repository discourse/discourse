# frozen_string_literal: true

RSpec.describe "Assign | User Menu" do
  fab!(:admin)

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    SiteSetting.assign_enabled = true
    sign_in(admin)
  end

  describe "Assign tab ordering" do
    fab!(:newest_topic) { Fabricate(:topic, bumped_at: 1.hour.ago) }
    fab!(:middle_topic) { Fabricate(:topic, bumped_at: 2.hours.ago) }
    fab!(:oldest_topic) { Fabricate(:topic, bumped_at: 3.hours.ago) }

    fab!(:older_unread_assign) do
      Fabricate(:assignment_notification, user: admin, topic: oldest_topic)
    end

    fab!(:newer_read_assign) do
      Fabricate(:assignment_notification, user: admin, topic: newest_topic, read: true)
    end

    fab!(:middle_unread_group_assign) do
      Fabricate(:assignment_notification, user: admin, topic: middle_topic, group: true)
    end

    it "keeps unread items first and orders them by topic bump date" do
      visit "/"
      user_menu.open
      user_menu.click_assignments_tab
      expect(user_menu).to have_assignments_in_order(
        [middle_unread_group_assign, older_unread_assign, newer_read_assign].map do
          it.topic.fancy_title
        end,
      )
    end
  end
end
