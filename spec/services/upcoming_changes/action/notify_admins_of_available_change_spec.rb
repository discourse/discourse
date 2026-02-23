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
        test_upcoming_change_b: {
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

    it "creates notifications with array data format" do
      result

      data = JSON.parse(notification.data)
      expect(data["upcoming_change_names"]).to eq(["test_upcoming_change"])
      expect(data["upcoming_change_humanized_names"]).to eq(
        [SiteSetting.humanized_name(:test_upcoming_change)],
      )
      expect(data["count"]).to eq(1)
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

    context "when there is an existing unread notification" do
      before do
        Fabricate(
          :notification,
          user: admin_1,
          notification_type: Notification.types[:upcoming_change_available],
          read: false,
          data: {
            upcoming_change_names: ["test_upcoming_change_b"],
            upcoming_change_humanized_names: [SiteSetting.humanized_name(:test_upcoming_change_b)],
            count: 1,
          }.to_json,
        )
      end

      it "consolidates into a single notification per admin" do
        result

        notifications =
          Notification.where(
            notification_type: Notification.types[:upcoming_change_available],
            user_id: admin_1.id,
          )
        expect(notifications.count).to eq(1)

        data = JSON.parse(notifications.first.data)
        expect(data["upcoming_change_names"]).to contain_exactly(
          "test_upcoming_change_b",
          "test_upcoming_change",
        )
        expect(data["count"]).to eq(2)
      end
    end

    context "when there is an existing read notification" do
      before do
        Fabricate(
          :notification,
          user: admin_1,
          notification_type: Notification.types[:upcoming_change_available],
          read: true,
          data: {
            upcoming_change_names: ["test_upcoming_change_b"],
            upcoming_change_humanized_names: [SiteSetting.humanized_name(:test_upcoming_change_b)],
            count: 1,
          }.to_json,
        )
      end

      it "does not consolidate with the read notification" do
        result

        notifications =
          Notification.where(
            notification_type: Notification.types[:upcoming_change_available],
            user_id: admin_1.id,
          )
        expect(notifications.count).to eq(2)
      end
    end

    context "when the same change is already in an unread notification" do
      before do
        Fabricate(
          :notification,
          user: admin_1,
          notification_type: Notification.types[:upcoming_change_available],
          read: false,
          data: {
            upcoming_change_names: ["test_upcoming_change"],
            upcoming_change_humanized_names: [SiteSetting.humanized_name(:test_upcoming_change)],
            count: 1,
          }.to_json,
        )
      end

      it "deduplicates the change names" do
        result

        notifications =
          Notification.where(
            notification_type: Notification.types[:upcoming_change_available],
            user_id: admin_1.id,
          )
        expect(notifications.count).to eq(1)

        data = JSON.parse(notifications.first.data)
        expect(data["upcoming_change_names"]).to eq(["test_upcoming_change"])
        expect(data["count"]).to eq(1)
      end
    end

    context "when there is an existing notification with the old data format" do
      before do
        Fabricate(
          :notification,
          user: admin_1,
          notification_type: Notification.types[:upcoming_change_available],
          read: false,
          data: {
            upcoming_change_name: "test_upcoming_change_b",
            upcoming_change_humanized_name: SiteSetting.humanized_name(:test_upcoming_change_b),
          }.to_json,
        )
      end

      it "merges old format into the new array format" do
        result

        notifications =
          Notification.where(
            notification_type: Notification.types[:upcoming_change_available],
            user_id: admin_1.id,
          )
        expect(notifications.count).to eq(1)

        data = JSON.parse(notifications.first.data)
        expect(data["upcoming_change_names"]).to contain_exactly(
          "test_upcoming_change_b",
          "test_upcoming_change",
        )
        expect(data["count"]).to eq(2)
      end
    end
  end
end
