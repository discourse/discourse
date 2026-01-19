# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::TrackAddedChanges do
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

  describe ".call" do
    subject(:result) { described_class.call(all_admins: [admin_1, admin_2]) }

    before { scoped_events.where(event_type: :added).delete_all }

    it "creates UpcomingChangeEvent entries for new upcoming changes" do
      expect { result }.to change { scoped_events.where(event_type: :added).count }.by(2)
    end

    it "returns the added changes" do
      expect(result[:added_changes]).to include(:enable_upload_debug_mode, :show_user_menu_avatars)
    end

    context "when there are previously added changes" do
      before do
        UpcomingChangeEvent.create!(
          event_type: :added,
          upcoming_change_name: :enable_upload_debug_mode,
        )
      end

      it "does not re-record previously added changes" do
        expect { result }.not_to change {
          scoped_events.where(
            event_type: :added,
            upcoming_change_name: :enable_upload_debug_mode,
          ).count
        }
      end

      it "returns only the newly added changes for the scoped settings" do
        expect(result[:added_changes]).to include(:show_user_menu_avatars)
        expect(result[:added_changes]).not_to include(:enable_upload_debug_mode)
      end
    end

    context "when the change status meets promotion_status - 1" do
      let(:show_user_menu_avatars_status) { :beta }

      before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

      it "notifies all admins" do
        expect { result }.to change {
          Notification
            .where(notification_type: Notification.types[:upcoming_change_available])
            .where("data::text LIKE ?", "%show_user_menu_avatars%")
            .count
        }.by(2)
      end

      it "includes the change in notified_changes" do
        expect(result[:notified_changes]).to include(:show_user_menu_avatars)
      end

      it "creates an admins_notified_available_change event" do
        expect { result }.to change {
          scoped_events.where(
            event_type: :admins_notified_available_change,
            upcoming_change_name: :show_user_menu_avatars,
          ).count
        }.by(1)
      end

      it "creates a UserHistory entry for the upcoming change" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:upcoming_change_available],
            subject: "show_user_menu_avatars",
          ).count
        }.by(1)
      end
    end

    context "when the change status does not meet promotion_status - 1" do
      let(:enable_upload_debug_mode_status) { :alpha }
      let(:show_user_menu_avatars_status) { :alpha }

      before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

      it "does not notify admins for the scoped alpha changes" do
        result
        expect(
          Notification
            .where(notification_type: Notification.types[:upcoming_change_available])
            .where("data::text LIKE ?", "%enable_upload_debug_mode%")
            .count,
        ).to eq(0)
        expect(
          Notification
            .where(notification_type: Notification.types[:upcoming_change_available])
            .where("data::text LIKE ?", "%show_user_menu_avatars%")
            .count,
        ).to eq(0)
      end

      it "does not include the scoped changes in notified_changes" do
        expect(result[:notified_changes]).not_to include(:enable_upload_debug_mode)
        expect(result[:notified_changes]).not_to include(:show_user_menu_avatars)
      end
    end

    context "when change is added at exactly promotion status threshold" do
      let(:show_user_menu_avatars_status) { :stable }

      before { SiteSetting.promote_upcoming_changes_on_status = "stable" }

      it "does not notify admins (Promote service will handle it)" do
        result
        expect(
          Notification
            .where(notification_type: Notification.types[:upcoming_change_available])
            .where("data::text LIKE ?", "%show_user_menu_avatars%")
            .count,
        ).to eq(0)
      end

      it "does not include the change in notified_changes" do
        expect(result[:notified_changes]).not_to include(:show_user_menu_avatars)
      end
    end
  end
end
