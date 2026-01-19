# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::TrackRemovedChanges do
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
      upcoming_change_name: %i[enable_upload_debug_mode show_user_menu_avatars old_removed_change],
    )
  end

  describe ".call" do
    subject(:result) { described_class.call }

    before do
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :old_removed_change)
      scoped_events.where(event_type: :removed).delete_all
    end

    it "creates a removed event for changes no longer in site settings" do
      expect { result }.to change {
        UpcomingChangeEvent.where(
          event_type: :removed,
          upcoming_change_name: :old_removed_change,
        ).count
      }.by(1)
    end

    it "returns the removed changes" do
      expect(result).to include(:old_removed_change)
    end

    it "does not create a removed event for current changes" do
      expect { result }.not_to change {
        scoped_events.where(
          event_type: :removed,
          upcoming_change_name: :enable_upload_debug_mode,
        ).count
      }
    end

    context "when there are previously removed changes" do
      before do
        UpcomingChangeEvent.create!(event_type: :removed, upcoming_change_name: :old_removed_change)
      end

      it "does not re-record previously removed changes" do
        expect { result }.not_to change {
          UpcomingChangeEvent.where(
            event_type: :removed,
            upcoming_change_name: :old_removed_change,
          ).count
        }
      end

      it "does not include previously removed changes in result" do
        expect(result).not_to include(:old_removed_change)
      end
    end
  end
end
