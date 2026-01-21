# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::NotifyAdminsOfAvailableChange do
  subject(:result) { described_class.call(change_name:, all_admins:) }

  before do
    mock_upcoming_change_metadata(
      {
        test_upcoming_change: {
          impact: "feature,all_members",
          status: :beta,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )
  end

  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)

  let(:all_admins) { [admin_1, admin_2] }
  let(:change_name) { :test_upcoming_change }

  describe ".call" do
    let(:notification) do
      Notification.find_by(
        notification_type: Notification.types[:upcoming_change_available],
        user_id: admin_1.id,
      )
    end

    it "returns true" do
      expect(result).to eq(true)
    end

    it "creates a notification for each admin" do
      expect { result }.to change {
        Notification.where(notification_type: Notification.types[:upcoming_change_available]).count
      }.by(2)
    end

    it "creates notifications with correct data" do
      result

      expect(JSON.parse(notification.data)).to include(
        "upcoming_change_name" => "test_upcoming_change",
        "upcoming_change_humanized_name" => SiteSetting.humanized_name(:test_upcoming_change),
      )
    end

    it "creates an admins_notified_available_change event" do
      expect { result }.to change {
        UpcomingChangeEvent.where(
          event_type: :admins_notified_available_change,
          upcoming_change_name: :test_upcoming_change,
        ).count
      }.by(1)
    end

    it "logs a staff action" do
      expect { result }.to change {
        UserHistory.where(
          action: UserHistory.actions[:upcoming_change_available],
          subject: "test_upcoming_change",
        ).count
      }.by(1)
    end
  end
end
