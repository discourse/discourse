# frozen_string_literal: true

describe "Assign | Viewing another user's preferences" do
  fab!(:admin)
  fab!(:assignable_user, :user)
  fab!(:other_user, :user)
  fab!(:group) { Fabricate(:group, users: [assignable_user]) }

  let(:user_preferences_notifications_page) { PageObjects::Pages::UserPreferencesNotifications.new }
  let(:remind_assigns_frequency) { PageObjects::Components::RemindAssignsFrequency.new }

  before do
    SiteSetting.assign_enabled = true
    SiteSetting.assign_allowed_on_groups = group.id.to_s
    sign_in(admin)
  end

  it "shows the reminder frequency only when the viewed user can assign" do
    user_preferences_notifications_page.visit(other_user)

    expect(remind_assigns_frequency).to have_no_frequency

    user_preferences_notifications_page.visit(assignable_user)

    expect(remind_assigns_frequency).to have_frequency
  end
end
