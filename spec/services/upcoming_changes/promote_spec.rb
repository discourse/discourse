# frozen_string_literal: true

RSpec.describe UpcomingChanges::Promote do
  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)
    let(:current_change_status) { :beta }
    let(:dependencies) { { guardian: } }
    let(:guardian) { admin.guardian }
    let(:params) { { setting_name: :enable_upload_debug_mode, promotion_status_threshold: } }

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

    context "when the upcoming change does not meet the status promotion criteria" do
      let(:promotion_status_threshold) { :stable }
      it { is_expected.to fail_a_policy(:meets_promotion_criteria) }
    end

    context "when the underlying setting for the upcoming change already exists in the DB (admin has modified it)" do
      let(:promotion_status_threshold) { :beta }

      before do
        SiteSetting.enable_upload_debug_mode = false
        DB.exec(
          "INSERT INTO site_settings (name, value, data_type, created_at, updated_at)
          VALUES ('enable_upload_debug_mode', 'false', 5, NOW(), NOW())",
        )
      end

      after { DB.exec("DELETE FROM site_settings WHERE name = 'enable_upload_debug_mode'") }

      it { is_expected.to fail_a_policy(:setting_not_modified) }

      context "when the current_change_status is permanent" do
        let(:current_change_status) { :permanent }

        it "enables the upcoming change setting" do
          expect(SiteSetting.enable_upload_debug_mode).to be_falsey
          result
          expect(SiteSetting.enable_upload_debug_mode).to be_truthy
        end

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
      end
    end

    context "when the upcoming change is already enabled" do
      let(:promotion_status_threshold) { :beta }

      before { SiteSetting.enable_upload_debug_mode = true }

      it { is_expected.to fail_a_policy(:setting_not_already_enabled) }
    end

    context "when everything is ok" do
      let(:promotion_status_threshold) { :beta }

      it { is_expected.to run_successfully }

      it "enables the upcoming change setting" do
        expect(SiteSetting.enable_upload_debug_mode).to be_falsey
        result
        expect(SiteSetting.enable_upload_debug_mode).to be_truthy
      end

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
    end
  end
end
