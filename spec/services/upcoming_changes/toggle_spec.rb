# frozen_string_literal: true

RSpec.describe UpcomingChanges::Toggle do
  describe UpcomingChanges::Toggle::Contract, type: :model do
    it { is_expected.to validate_presence_of :setting_name }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies, options:) }

    fab!(:admin)
    let(:params) { { setting_name:, enabled: } }
    let(:enabled) { true }
    let(:setting_name) { :experimental_form_templates }
    let(:dependencies) { { guardian: } }
    let(:options) { {} }
    let(:guardian) { admin.guardian }

    context "when data is invalid" do
      let(:setting_name) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when setting_name is invalid" do
      let(:setting_name) { "wrong_value" }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      context "when enable_upcoming_changes is disabled" do
        context "when log_change is true" do
          let(:options) { { log_change: true } }

          context "when enabling the setting" do
            let(:enabled) { true }

            before { SiteSetting.experimental_form_templates = false }

            it "enables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(true)
            end

            it "creates an entry in the staff action logs" do
              expect { result }.to change {
                UserHistory.where(
                  action: UserHistory.actions[:change_site_setting],
                  subject: "experimental_form_templates",
                ).count
              }.by(1)
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end

          context "when disabling the setting" do
            let(:enabled) { false }

            before { SiteSetting.experimental_form_templates = true }

            it "disables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(false)
            end

            it "creates an entry in the staff action logs" do
              expect { result }.to change {
                UserHistory.where(
                  action: UserHistory.actions[:change_site_setting],
                  subject: "experimental_form_templates",
                ).count
              }.by(1)
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end
        end

        context "when log_change is false" do
          let(:options) { { log_change: false } }

          context "when enabling the setting" do
            let(:enabled) { true }

            before { SiteSetting.experimental_form_templates = false }

            it "enables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(true)
            end

            it "does not create an entry in the staff action logs" do
              expect { result }.not_to change {
                UserHistory.where(
                  action: UserHistory.actions[:change_site_setting],
                  subject: "experimental_form_templates",
                ).count
              }
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end

          context "when disabling the setting" do
            let(:enabled) { false }

            before { SiteSetting.experimental_form_templates = true }

            it "disables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(false)
            end

            it "does not create an entry in the staff action logs" do
              expect { result }.not_to change {
                UserHistory.where(
                  action: UserHistory.actions[:change_site_setting],
                  subject: "experimental_form_templates",
                ).count
              }
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end
        end
      end

      context "when enable_upcoming_changes is enabled" do
        before { SiteSetting.enable_upcoming_changes = true }

        context "when log_change is true" do
          let(:options) { { log_change: true } }

          context "when enabling the setting" do
            let(:enabled) { true }

            before { SiteSetting.experimental_form_templates = false }

            it "enables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(true)
            end

            it "creates an entry in the staff action logs with correct context" do
              expect { result }.to change {
                UserHistory.where(
                  action: UserHistory.actions[:upcoming_change_toggled],
                  subject: "experimental_form_templates",
                ).count
              }.by(1)

              expect(UserHistory.last.context).to eq(
                I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled"),
              )
            end

            it "creates an UpcomingChangeEvent with manual_opt_in event_type" do
              expect { result }.to change {
                UpcomingChangeEvent.where(
                  event_type: :manual_opt_in,
                  upcoming_change_name: "experimental_form_templates",
                ).count
              }.by(1)
            end
          end

          context "when disabling the setting" do
            let(:enabled) { false }

            before { SiteSetting.experimental_form_templates = true }

            it "disables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(false)
            end

            it "creates an entry in the staff action logs with correct context" do
              expect { result }.to change {
                UserHistory.where(
                  action: UserHistory.actions[:upcoming_change_toggled],
                  subject: "experimental_form_templates",
                ).count
              }.by(1)

              expect(UserHistory.last.context).to eq(
                I18n.t("staff_action_logs.upcoming_changes.log_manually_toggled"),
              )
            end

            it "creates an UpcomingChangeEvent with manual_opt_out event_type" do
              expect { result }.to change {
                UpcomingChangeEvent.where(
                  event_type: :manual_opt_out,
                  upcoming_change_name: "experimental_form_templates",
                ).count
              }.by(1)
            end
          end
        end

        context "when log_change is false" do
          let(:options) { { log_change: false } }

          context "when enabling the setting" do
            let(:enabled) { true }

            before { SiteSetting.experimental_form_templates = false }

            it "enables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(true)
            end

            it "does not create an entry in the staff action logs" do
              expect { result }.not_to change {
                UserHistory.where(
                  action: UserHistory.actions[:upcoming_change_toggled],
                  subject: "experimental_form_templates",
                ).count
              }
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end

          context "when disabling the setting" do
            let(:enabled) { false }

            before { SiteSetting.experimental_form_templates = true }

            it "disables the specified setting" do
              expect { result }.to change { SiteSetting.experimental_form_templates }.to(false)
            end

            it "does not create an entry in the staff action logs" do
              expect { result }.not_to change {
                UserHistory.where(
                  action: UserHistory.actions[:upcoming_change_toggled],
                  subject: "experimental_form_templates",
                ).count
              }
            end

            it "does not create an UpcomingChangeEvent" do
              expect { result }.not_to change { UpcomingChangeEvent.count }
            end
          end
        end
      end
    end
  end
end
