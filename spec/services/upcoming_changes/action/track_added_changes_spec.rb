# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::TrackAddedChanges do
  before do
    mock_upcoming_change_metadata(
      {
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :experimental,
          impact_type: "other",
          impact_role: "developers",
        },
        show_user_menu_avatars: {
          impact: "feature,all_members",
          status: :beta,
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
      expect(result).to include(:enable_upload_debug_mode, :show_user_menu_avatars)
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
        expect(result).to include(:show_user_menu_avatars)
        expect(result).not_to include(:enable_upload_debug_mode)
      end
    end
  end
end
