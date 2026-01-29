# frozen_string_literal: true

RSpec.describe UpcomingChanges::NotifyPromotion do
  describe ".call" do
    subject(:result) do
      described_class.call(
        params: {
          setting_name:,
          admin_user_ids:,
          changes_already_notified_about_promotion:,
        },
        guardian: Discourse.system_user.guardian,
      )
    end

    fab!(:admin)
    fab!(:admin_2, :admin)

    let(:setting_name) { :enable_upload_debug_mode }
    let(:admin_user_ids) { [admin.id, admin_2.id] }
    let(:changes_already_notified_about_promotion) { [] }
    let(:setting_status) { :stable }

    before do
      SiteSetting.promote_upcoming_changes_on_status = :stable
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          impact: "other,developers",
          status: setting_status,
          impact_type: "other",
          impact_role: "developers",
        },
      )
    end

    context "when data is invalid" do
      context "when setting_name is missing" do
        let(:setting_name) { nil }

        it { is_expected.to fail_a_contract }
      end

      context "when admin_user_ids is missing" do
        let(:admin_user_ids) { [] }

        it { is_expected.to fail_a_contract }
      end
    end

    context "when setting is not available" do
      let(:setting_name) { :nonexistent_setting }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when setting does not meet or exceed promotion status" do
      let(:setting_status) { :beta }

      it { is_expected.to fail_a_policy(:meets_or_exceeds_status) }
    end

    context "when change has already been notified about promotion" do
      let(:changes_already_notified_about_promotion) { [:enable_upload_debug_mode] }

      it { is_expected.to fail_a_policy(:change_has_not_already_been_notified_about_promotion) }
    end

    context "when admin has manually opted out" do
      before { SiteSetting.enable_upload_debug_mode = false }

      it { is_expected.to fail_a_policy(:admin_has_not_manually_opted_out) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      it "logs the change context in the staff action log" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:upcoming_change_toggled],
            subject: "enable_upload_debug_mode",
          ).count
        }.by(1)

        expect(UserHistory.last.context).to eq(
          I18n.t(
            "staff_action_logs.upcoming_changes.log_promoted",
            change_status: UpcomingChanges.change_status(:enable_upload_debug_mode).to_s.titleize,
            base_path: Discourse.base_path,
          ),
        )
      end

      it "notifies admins about the upcoming change" do
        expect { result }.to change {
          Notification
            .where(
              notification_type: Notification.types[:upcoming_change_automatically_promoted],
              user_id: [admin.id, admin_2.id],
            )
            .where("data::text LIKE ?", "%enable_upload_debug_mode%")
            .count
        }.by(2)

        notification = Notification.where("data::text LIKE ?", "%enable_upload_debug_mode%").last
        expect(notification.data).to eq(
          {
            upcoming_change_name: :enable_upload_debug_mode,
            upcoming_change_humanized_name: "Enable upload debug mode",
          }.to_json,
        )
      end

      it "creates an admins_notified_automatic_promotion event" do
        expect { result }.to change {
          UpcomingChangeEvent.where(
            event_type: :admins_notified_automatic_promotion,
            upcoming_change_name: :enable_upload_debug_mode,
          ).count
        }.by(1)
      end

      it "triggers DiscourseEvent for the promoted setting" do
        events = DiscourseEvent.track_events { result }
        event =
          events.find do |e|
            e[:event_name] == :upcoming_change_enabled &&
              e[:params].first == :enable_upload_debug_mode
          end

        expect(event).to be_present
        expect(event[:params]).to eq([:enable_upload_debug_mode])
      end
    end
  end
end
