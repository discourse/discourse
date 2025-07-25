# frozen_string_literal: true

RSpec.describe "Assign | User Menu", type: :system, js: true do
  fab!(:admin)

  let(:user_menu) { PageObjects::Components::UserMenu.new }

  before do
    SiteSetting.assign_enabled = true
    sign_in(admin)
  end

  describe "Assign tab ordering" do
    let!(:unread_user_assign) { Fabricate(:assignment_notification, user: admin) }
    let!(:unread_user_assign_2) { Fabricate(:assignment_notification, user: admin) }
    let!(:read_user_assign) { Fabricate(:assignment_notification, user: admin, read: true) }
    let!(:read_user_assign_2) { Fabricate(:assignment_notification, user: admin, read: true) }
    let!(:unread_group_assign) { Fabricate(:assignment_notification, user: admin, group: true) }
    let!(:read_group_assign) do
      Fabricate(:assignment_notification, user: admin, read: true, group: true)
    end
    let(:expected_order) do
      [
        unread_user_assign_2,
        unread_user_assign,
        unread_group_assign,
        read_user_assign_2,
        read_user_assign,
        read_group_assign,
      ].map { _1.topic.fancy_title }
    end

    it "orders the items properly" do
      visit "/"
      user_menu.open
      user_menu.click_assignments_tab
      expect(user_menu).to have_assignments_in_order(expected_order)
    end
  end
end
