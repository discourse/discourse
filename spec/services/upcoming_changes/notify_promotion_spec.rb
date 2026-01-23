# frozen_string_literal: true

RSpec.describe UpcomingChanges::NotifyPromotion do
  describe UpcomingChanges::NotifyPromotion::Contract, type: :model do
    subject(:contract) { described_class.new }

    it { is_expected.to validate_presence_of(:setting_name) }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    let(:current_change_status) { :beta }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:params) { { setting_name: :enable_upload_debug_mode } }

    before do
      mock_upcoming_change_metadata(
        {
          enable_upload_debug_mode: {
            impact: "other,developers",
            status: current_change_status,
            impact_type: "other",
            impact_role: "developers",
          },
        },
      )
    end

    context "when contract is invalid" do
      let(:params) { {} }

      it { is_expected.to fail_a_contract }
    end

    context "when setting does not exist" do
      let(:params) { { setting_name: :nonexistent_setting } }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when everything is ok" do
      fab!(:admin_2, :admin)

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
          Notification.where(
            notification_type: Notification.types[:upcoming_change_automatically_promoted],
            user_id: [admin.id, admin_2.id],
          ).count
        }.by(2)

        expect(Notification.last.data).to eq(
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
    end
  end
end
