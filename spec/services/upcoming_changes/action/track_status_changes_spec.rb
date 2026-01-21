# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::TrackStatusChanges do
  let(:enable_upload_debug_mode_status) { :experimental }
  let(:show_user_menu_avatars_status) { :beta }

  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: enable_upload_debug_mode_status,
          impact_type: "other",
          impact_role: "developers",
        },
        show_user_menu_avatars: {
          impact: "feature,all_members",
          status: show_user_menu_avatars_status,
          impact_type: "feature",
          impact_role: "all_members",
        },
      },
    )
  end

  def scoped_events
    UpcomingChangeEvent.where(
      upcoming_change_name: %i[enable_upload_debug_mode show_user_menu_avatars],
    )
  end

  fab!(:admin_1, :admin)
  fab!(:admin_2, :admin)
  let(:added_changes) { [] }
  let(:removed_changes) { [] }

  describe ".call" do
    subject(:result) do
      described_class.call(all_admins: [admin_1, admin_2], added_changes:, removed_changes:)
    end

    before do
      scoped_events.where(event_type: :status_changed).delete_all
      scoped_events.where(event_type: :added).delete_all
      UpcomingChangeEvent.create!(
        event_type: :added,
        upcoming_change_name: :enable_upload_debug_mode,
      )
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :show_user_menu_avatars)
    end

    context "when there are no previous status changes" do
      it "creates a status_changed event for the current status" do
        expect { result }.to change { scoped_events.where(event_type: :status_changed).count }.by(2)
      end

      it "sets previous_value to nil in the event data" do
        result
        event =
          scoped_events.find_by(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
          )
        expect(event.event_data["previous_value"]).to be_nil
      end

      it "sets new_value to the current status in the event data" do
        result
        event =
          scoped_events.find_by(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
          )
        expect(event.event_data["new_value"]).to eq("experimental")
      end

      it "returns N/A as previous_value in the result" do
        expect(result[:status_changes][:enable_upload_debug_mode]).to eq(
          { previous_value: "N/A", new_value: :experimental },
        )
      end
    end

    context "when there are added changes in the same run" do
      let(:added_changes) { [:enable_upload_debug_mode] }

      before do
        scoped_events.where(event_type: :added).delete_all
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :enable_upload_debug_mode,
          event_data: {
            "previous_value" => nil,
            "new_value" => "alpha",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :show_user_menu_avatars,
          event_data: {
            "previous_value" => nil,
            "new_value" => "beta",
          },
        )
      end

      it "does not create additional status change events for added changes" do
        expect { result }.not_to change {
          scoped_events.where(
            event_type: :status_changed,
            upcoming_change_name: :enable_upload_debug_mode,
          ).count
        }
      end
    end

    context "when there are removed changes in the same run" do
      let(:removed_changes) { [:old_removed_change] }

      before do
        UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :old_removed_change)
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :old_removed_change,
          event_data: {
            "previous_value" => nil,
            "new_value" => "beta",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :enable_upload_debug_mode,
          event_data: {
            "previous_value" => nil,
            "new_value" => "experimental",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :show_user_menu_avatars,
          event_data: {
            "previous_value" => nil,
            "new_value" => "beta",
          },
        )
      end

      it "does not create a status change event for removed changes" do
        expect { result }.not_to change {
          UpcomingChangeEvent.where(
            event_type: :status_changed,
            upcoming_change_name: :old_removed_change,
          ).count
        }
      end
    end

    context "when the status has changed from a previous value" do
      let(:show_user_menu_avatars_status) { :stable }

      before do
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :show_user_menu_avatars,
          event_data: {
            "previous_value" => nil,
            "new_value" => "beta",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :enable_upload_debug_mode,
          event_data: {
            "previous_value" => nil,
            "new_value" => "experimental",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :admins_notified_available_change,
          upcoming_change_name: :show_user_menu_avatars,
        )
      end

      it "creates a status_changed event with correct data" do
        expect { result }.to change {
          scoped_events.where(
            event_type: :status_changed,
            upcoming_change_name: :show_user_menu_avatars,
          ).count
        }.by(1)
      end

      it "records the previous and new status values" do
        result
        result
        expect(
          scoped_events
            .where(event_type: :status_changed, upcoming_change_name: :show_user_menu_avatars)
            .order(:created_at)
            .last,
        ).to have_attributes(event_data: { "previous_value" => "beta", "new_value" => "stable" })
      end

      it "returns the status change in the result" do
        expect(result[:status_changes][:show_user_menu_avatars]).to eq(
          { previous_value: "beta", new_value: :stable },
        )
      end
    end

    context "when status has not changed" do
      let(:show_user_menu_avatars_status) { :beta }

      before do
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :show_user_menu_avatars,
          event_data: {
            "previous_value" => nil,
            "new_value" => "beta",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :enable_upload_debug_mode,
          event_data: {
            "previous_value" => nil,
            "new_value" => "experimental",
          },
        )
      end

      it "does not create a new status_changed event" do
        expect { result }.not_to change { scoped_events.where(event_type: :status_changed).count }
      end
    end

    context "when an added change did not meet promotion_status - 1 initially" do
      let(:show_user_menu_avatars_status) { :beta }

      before do
        SiteSetting.promote_upcoming_changes_on_status = "stable"
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :show_user_menu_avatars,
          event_data: {
            "previous_value" => nil,
            "new_value" => "alpha",
          },
        )
        UpcomingChangeEvent.create!(
          event_type: :status_changed,
          upcoming_change_name: :enable_upload_debug_mode,
          event_data: {
            "previous_value" => nil,
            "new_value" => "experimental",
          },
        )
      end

      it "notifies all admins when status now meets threshold" do
        expect { result }.to change {
          Notification
            .where(
              notification_type: Notification.types[:upcoming_change_available],
              user_id: [admin_1.id, admin_2.id],
            )
            .where("data::text LIKE ?", "%show_user_menu_avatars%")
            .count
        }.by(2)
      end

      it "creates an admins_notified_available_change event" do
        expect { result }.to change {
          scoped_events.where(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :show_user_menu_avatars,
          ).count
        }.by(1)
      end

      it "includes the change in notified_changes" do
        expect(result[:notified_changes]).to include(:show_user_menu_avatars)
      end

      it "creates a UserHistory entry for the upcoming change" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:upcoming_change_available],
            subject: "show_user_menu_avatars",
          ).count
        }.by(1)
      end

      context "when admins were already notified" do
        before do
          UpcomingChangeEvent.create!(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :show_user_menu_avatars,
          )
        end

        it "does not notify admins again" do
          expect { result }.not_to change {
            Notification
              .where(notification_type: Notification.types[:upcoming_change_available])
              .where("data::text LIKE ?", "%show_user_menu_avatars%")
              .count
          }
        end

        it "does not include the change in notified_changes" do
          expect(result[:notified_changes]).not_to include(:show_user_menu_avatars)
        end
      end
    end
  end
end
