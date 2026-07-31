# frozen_string_literal: true

RSpec.describe UpcomingChanges::Action::BackfillNotifiedEvents do
  let(:change_names) do
    %i[enable_upload_debug_mode show_user_menu_avatars enable_experimental_admin_ui_grouped_filters]
  end

  before do
    SiteSetting.promote_upcoming_changes_on_status = :beta

    mock_upcoming_change_metadata(
      {
        # Below the "available" threshold (alpha), so not notifiable yet.
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: :experimental,
          impact_type: "other",
          impact_role: "developers",
        },
        # At the "available" threshold.
        show_user_menu_avatars: {
          impact: "feature,all_members",
          status: :alpha,
          impact_type: "feature",
          impact_role: "all_members",
        },
        # At/above the promotion threshold.
        enable_experimental_admin_ui_grouped_filters: {
          impact: "feature,admins",
          status: :stable,
          impact_type: "feature",
          impact_role: "admins",
        },
      },
    )

    scoped_events.delete_all
  end

  def scoped_events
    UpcomingChangeEvent.where(upcoming_change_name: change_names)
  end

  def event_types_for(change_name)
    scoped_events.where(upcoming_change_name: change_name).pluck(:event_type).map(&:to_sym)
  end

  describe ".call" do
    subject(:result) { described_class.call(upcoming_change_names: change_names) }

    it "records every change as added" do
      result

      expect(scoped_events.where(event_type: :added).pluck(:upcoming_change_name)).to match_array(
        change_names.map(&:to_s),
      )
    end

    it "does not mark a change below the available threshold as notified about" do
      result

      expect(event_types_for(:enable_upload_debug_mode)).to contain_exactly(:added)
    end

    it "marks a change at the available threshold as notified about availability" do
      result

      expect(event_types_for(:show_user_menu_avatars)).to contain_exactly(
        :added,
        :admins_notified_available_change,
      )
    end

    it "marks a change at the promotion threshold as notified about promotion" do
      result

      expect(event_types_for(:enable_experimental_admin_ui_grouped_filters)).to contain_exactly(
        :added,
        :admins_notified_automatic_promotion,
      )
    end

    it "does not promote anything itself" do
      result

      expect(scoped_events.where(event_type: :automatically_promoted)).to be_empty
    end

    it "returns the changes it backfilled" do
      expect(result).to match_array(change_names)
    end

    it "is idempotent" do
      described_class.call(change_names: change_names)

      expect { result }.not_to change { scoped_events.count }
    end

    it "does not duplicate events that already exist" do
      UpcomingChangeEvent.create!(event_type: :added, upcoming_change_name: :show_user_menu_avatars)

      result

      expect(event_types_for(:show_user_menu_avatars)).to contain_exactly(
        :added,
        :admins_notified_available_change,
      )
    end

    context "when no change names are given" do
      subject(:result) { described_class.call(upcoming_change_names: []) }

      it "does nothing" do
        expect { result }.not_to change { UpcomingChangeEvent.count }
      end
    end

    context "when change names are not passed" do
      subject(:result) { described_class.call }

      it "backfills every upcoming change on the site" do
        result

        expect(
          UpcomingChangeEvent.where(
            event_type: :added,
            upcoming_change_name: SiteSetting.upcoming_change_site_settings,
          ).count,
        ).to eq(SiteSetting.upcoming_change_site_settings.count)
      end
    end
  end
end
