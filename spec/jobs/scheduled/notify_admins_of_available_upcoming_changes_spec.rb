# frozen_string_literal: true

RSpec.describe Jobs::NotifyAdminsOfAvailableUpcomingChanges do
  subject(:result) { described_class.new.execute({}) }

  before do
    mock_upcoming_change_metadata(
      {
        test_upcoming_change: {
          impact: "feature,all_members",
          status: test_upcoming_change_status,
          impact_type: "feature",
          impact_role: "all_members",
        },
        test_upcoming_change_b: {
          impact: "feature,all_members",
          status: :beta,
          impact_type: "feature",
          impact_role: "all_members",
        },
        test_upcoming_change_c: {
          impact: "feature,all_members",
          status: :beta,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )

    # No upcoming change notifications are sent for new sites
    UpcomingChanges.stubs(:should_notify_admins?).returns(true)
  end

  let(:test_upcoming_change_status) { :beta }
  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)

  fab!(:new_change_log) do
    UpcomingChangeEvent.create!(
      event_type: :added,
      upcoming_change_name: :test_upcoming_change,
      created_at: 1.day.ago,
    )
  end
  fab!(:new_change_log_2) do
    UpcomingChangeEvent.create!(
      event_type: :added,
      upcoming_change_name: :test_upcoming_change_b,
      created_at: 3.days.ago,
    )
  end
  fab!(:old_change_log) do
    UpcomingChangeEvent.create!(
      event_type: :added,
      upcoming_change_name: :test_upcoming_change_c,
      created_at: 8.days.ago,
    )
  end

  it "creates a notification for each admin for the recently available changes that we have not yet notified" do
    expect { result }.to change {
      Notification.where(notification_type: Notification.types[:upcoming_change_available]).count
    }.by(2)
    expect(
      JSON.parse(
        Notification
          .where(notification_type: Notification.types[:upcoming_change_available])
          .last
          .data,
        symbolize_names: true,
      ),
    ).to include(
      upcoming_change_names: %w[test_upcoming_change test_upcoming_change_b],
      upcoming_change_humanized_names: ["Test upcoming change", "Test upcoming change b"],
      count: 2,
    )
  end

  it "does not create a notification for changes where we have notified the admins already" do
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_available_change,
      upcoming_change_name: :test_upcoming_change,
    )
    expect { result }.to change {
      Notification.where(notification_type: Notification.types[:upcoming_change_available]).count
    }.by(2)
    expect(
      JSON.parse(
        Notification
          .where(notification_type: Notification.types[:upcoming_change_available])
          .last
          .data,
        symbolize_names: true,
      ),
    ).to include(
      upcoming_change_names: %w[test_upcoming_change_b],
      upcoming_change_humanized_names: ["Test upcoming change b"],
      count: 1,
    )
  end

  it "does not create a notification for admins who have disabled upcoming change available notifications" do
    admin_1.user_option.update!(enable_upcoming_change_available_notifications: false)
    expect { result }.to change {
      Notification.where(notification_type: Notification.types[:upcoming_change_available]).count
    }.by(1)
    expect(
      Notification.where(
        user: admin_2,
        notification_type: Notification.types[:upcoming_change_available],
      ).count,
    ).to eq(1)
    expect(
      Notification.where(
        user: admin_1,
        notification_type: Notification.types[:upcoming_change_available],
      ).count,
    ).to eq(0)
  end

  it "does not create a notification if we've already automatically promoted the change" do
    UpcomingChangeEvent.create!(
      event_type: :admins_notified_automatic_promotion,
      upcoming_change_name: :test_upcoming_change,
      acting_user: Discourse.system_user,
    )
    result
    expect(
      JSON.parse(
        Notification
          .where(notification_type: Notification.types[:upcoming_change_available])
          .last
          .data,
        symbolize_names: true,
      ),
    ).to include(
      upcoming_change_names: %w[test_upcoming_change_b],
      upcoming_change_humanized_names: ["Test upcoming change b"],
      count: 1,
    )
  end

  it "creates a staff action log for each upcoming change that we are notifying for" do
    expect { result }.to change {
      UserHistory.where(action: UserHistory.actions[:upcoming_change_available]).count
    }.by(2)
  end

  it "creates an admins_notifed_available_change event for each upcoming change that we are notifying for" do
    expect { result }.to change {
      UpcomingChangeEvent.where(event_type: :admins_notified_available_change).count
    }.by(2)
  end

  context "when there are no upcoming changes to notify" do
    before { UpcomingChangeEvent.delete_all }

    it "sends no notifications" do
      expect { result }.not_to change { Notification.count }
    end

    context "when there are existing unread notifications" do
      fab!(:notification) do
        Fabricate(
          :notification,
          notification_type: Notification.types[:upcoming_change_available],
          user: admin_1,
        )
      end

      it "does not delete the existing notifications" do
        old_notification_id = notification.id
        result
        expect(Notification.find_by(id: old_notification_id)).to be_present
      end
    end
  end

  context "when admins should not be notified" do
    before { UpcomingChanges.stubs(:should_notify_admins?).returns(false) }

    it "sends no notifications" do
      expect { result }.not_to change { Notification.count }
    end
  end

  context "when an upcoming change has an old added event" do
    before { new_change_log.update!(created_at: 2.weeks.ago) }

    context "when there is not a recent status change event that matches promotion status - 1" do
      it "does not create notifications for that change" do
        result
        expect(
          JSON.parse(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .last
              .data,
            symbolize_names: true,
          ),
        ).to include(
          upcoming_change_names: %w[test_upcoming_change_b],
          upcoming_change_humanized_names: ["Test upcoming change b"],
          count: 1,
        )
      end
    end

    context "when there is also a recent status change event that matches promotion status - 1" do
      before do
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :test_upcoming_change,
          created_at: 1.day.ago,
          event_data: {
            new_value:
              UpcomingChanges.previous_status(SiteSetting.promote_upcoming_changes_on_status).to_s,
          },
        )
      end

      it "creates notifications for that change" do
        result
        expect(
          JSON.parse(
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .last
              .data,
            symbolize_names: true,
          ),
        ).to include(
          upcoming_change_names: %w[test_upcoming_change test_upcoming_change_b],
          upcoming_change_humanized_names: ["Test upcoming change", "Test upcoming change b"],
          count: 2,
        )
      end

      context "when we have already notified admins of the change" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :test_upcoming_change,
          )
        end

        it "does not make a notification for the change" do
          result
          expect(
            JSON.parse(
              Notification
                .where(notification_type: Notification.types[:upcoming_change_available])
                .last
                .data,
              symbolize_names: true,
            ),
          ).to include(
            upcoming_change_names: %w[test_upcoming_change_b],
            upcoming_change_humanized_names: ["Test upcoming change b"],
            count: 1,
          )
        end
      end
    end
  end

  context "when an admin has an unread notification from a previous week" do
    fab!(:notification) do
      Fabricate(
        :notification,
        notification_type: Notification.types[:upcoming_change_available],
        read: false,
        user: admin_1,
        data: {
          upcoming_change_names: ["test_upcoming_change_ancient"],
          upcoming_change_humanized_names: [
            SiteSetting.humanized_name(:test_upcoming_change_ancient),
          ],
          count: 1,
        }.to_json,
      )
    end

    it "consolidates the notifications including the upcoming change names" do
      existing_notification_id = notification.id
      expect { result }.to change { Notification.where(user_id: admin_2.id).count }.by(
        1,
      ).and not_change { Notification.where(user_id: admin_1.id).count }

      new_notification =
        Notification.find_by(
          user_id: admin_1.id,
          notification_type: Notification.types[:upcoming_change_available],
        )
      expect(Notification.find_by(id: existing_notification_id)).to be_nil
      data = JSON.parse(new_notification.reload.data)
      expect(data["upcoming_change_names"]).to contain_exactly(
        "test_upcoming_change_ancient",
        "test_upcoming_change",
        "test_upcoming_change_b",
      )
      expect(data["count"]).to eq(3)
    end
  end

  context "when all admins have disabled upcoming change available notifications" do
    before do
      admin_1.user_option.update!(enable_upcoming_change_available_notifications: false)
      admin_2.user_option.update!(enable_upcoming_change_available_notifications: false)
    end

    it "sends no notifications" do
      expect { result }.not_to change {
        Notification.where(notification_type: Notification.types[:upcoming_change_available]).count
      }
    end

    it "logs no staff action logs" do
      expect { result }.not_to change {
        UserHistory.where(action: UserHistory.actions[:upcoming_change_available]).count
      }
    end

    it "logs no admins_notifed_available_change events" do
      expect { result }.not_to change {
        UpcomingChangeEvent.where(event_type: :admins_notified_available_change).count
      }
    end
  end

  context "when an upcoming change should not be displayed on this site" do
    before do
      UpcomingChanges::ConditionalDisplay.stubs(:should_display_test_upcoming_change?).returns(
        false,
      )
    end

    it "does not create a notification for the hidden change but still notifies for others" do
      result
      data =
        JSON.parse(
          Notification
            .where(notification_type: Notification.types[:upcoming_change_available])
            .last
            .data,
          symbolize_names: true,
        )
      expect(data[:upcoming_change_names]).to eq(%w[test_upcoming_change_b])
      expect(data[:count]).to eq(1)
    end

    it "does not log an admins_notified_available_change event for the hidden change" do
      expect { result }.not_to change {
        UpcomingChangeEvent.where(
          event_type: :admins_notified_available_change,
          upcoming_change_name: :test_upcoming_change,
        ).count
      }
    end
  end

  context "when there is an added event for an upcoming change that no longer exists" do
    before do
      UpcomingChangeEvent.create!(
        event_type: :added,
        upcoming_change_name: :old_deleted_upcoming_change,
        created_at: 1.day.ago,
      )
    end

    it "does not create a notification for that change" do
      result
      expect(
        Notification
          .where(notification_type: Notification.types[:upcoming_change_available])
          .to_a
          .map { |notification| JSON.parse(notification.data)["upcoming_change_names"] || [] }
          .flatten,
      ).not_to include("old_deleted_upcoming_change")
    end
  end

  context "when an upcoming change is added but hasn't reached the promotion status - 1" do
    let(:test_upcoming_change_status) { :experimental }

    it "does not create a notification for that change" do
      result
      expect(
        Notification
          .where(notification_type: Notification.types[:upcoming_change_available])
          .to_a
          .map { |notification| JSON.parse(notification.data)["upcoming_change_names"] || [] }
          .flatten,
      ).not_to include("test_upcoming_change")
    end
  end
end
