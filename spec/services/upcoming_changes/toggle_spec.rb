# frozen_string_literal: true

RSpec.describe UpcomingChanges::Toggle do
  describe UpcomingChanges::Toggle::Contract, type: :model do
    it { is_expected.to validate_presence_of :setting_name }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies, options:) }

    fab!(:admin)

    before do
      mock_upcoming_change_metadata(
        enable_form_templates: {
          impact: "feature,all_members",
          status: :experimental,
        },
      )
    end

    let(:params) { { setting_name:, enabled: } }
    let(:enabled) { true }
    let(:setting_name) { :enable_form_templates }
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

    context "when setting_name is not an upcoming change" do
      let(:setting_name) { :notify_changed! }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when a non-admin user tries to change a setting" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when enabling with an explicit staff audience" do
      let(:params) { super().merge(group_names: ["staff"]) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: [:staff],
          },
        )
        SiteSetting.enable_form_templates = false
      end

      it "saves the required audience and enables the change together" do
        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq(
          Group::AUTO_GROUPS[:staff].to_s,
        )
      end
    end

    context "when an explicit audience contains an unknown group" do
      let(:params) { super().merge(group_names: %w[staff nonexistent_group]) }

      before do
        SiteSetting.enable_form_templates = false
        Fabricate(:site_setting_group, name: setting_name, group_ids: "3")
      end

      it "rejects the audience without applying its valid subset" do
        expect(result).to fail_to_find_a_model(:group_ids)
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3")
      end
    end

    context "when enabling with an audience outside the allowed targets" do
      let(:params) { super().merge(group_names: ["trust_level_2"]) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: [:staff],
          },
        )
        SiteSetting.enable_form_templates = false
        Fabricate(:site_setting_group, name: setting_name, group_ids: "3")
      end

      it "rejects the audience without changing the toggle or stored groups" do
        expect(result).to fail_a_policy(:allowed_enabled_for_target)
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3")
      end
    end

    context "when disabling a change with a saved audience" do
      let(:enabled) { false }

      before do
        SiteSetting.enable_form_templates = true
        Fabricate(:site_setting_group, name: setting_name, group_ids: "3|12")
      end

      it "keeps the audience for the next enablement" do
        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3|12")
      end
    end

    context "when everyone is selected explicitly for an unrestricted change" do
      let(:params) { super().merge(group_names: %w[logged_in_users anonymous_users staff]) }

      before do
        SiteSetting.enable_form_templates = false
        Fabricate(:site_setting_group, name: setting_name, group_ids: "3")
      end

      it "enables the change for everyone without storing group restrictions" do
        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSettingGroup.where(name: setting_name)).to be_empty
      end
    end

    context "when enabling a staff-inclusive change with additional groups" do
      let(:params) { super().merge(group_names: %w[staff trust_level_2]) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: %i[staff specific_groups],
          },
        )
        SiteSetting.enable_form_templates = false
      end

      it "enables the change for staff and the selected groups" do
        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3|12")
      end
    end

    context "when clearing the audience disables a specific-groups-only change" do
      let(:params) { super().merge(enabled: false, group_names: []) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: [:specific_groups],
          },
        )
        SiteSetting.enable_form_templates = true
        Fabricate(:site_setting_group, name: setting_name, group_ids: "12")
      end

      it "removes the audience and disables the change together" do
        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.where(name: setting_name)).to be_empty
      end
    end

    context "when a staff-inclusive change is enabled without staff" do
      let(:params) { super().merge(group_names: ["trust_level_2"]) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            allow_enabled_for: %i[staff specific_groups],
          },
        )
        SiteSetting.enable_form_templates = false
      end

      it "rejects the audience without enabling the change" do
        expect(result).to fail_a_policy(:allowed_enabled_for_target)
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSettingGroup.where(name: setting_name)).to be_empty
      end
    end

    context "when the audience comes from a linked group setting" do
      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            group_setting: :about_page_extra_groups,
          },
        )
        SiteSetting.about_page_extra_groups = "12"
        Fabricate(:site_setting_group, name: setting_name, group_ids: "3")
      end

      it "enables the flag without changing either audience store" do
        SiteSetting.enable_form_templates = false

        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSetting.about_page_extra_groups).to eq("12")
        expect(SiteSettingGroup.find_by(name: setting_name).group_ids).to eq("3")
      end

      it "enables the flag independently of an empty linked audience" do
        SiteSetting.enable_form_templates = false
        SiteSetting.about_page_extra_groups = ""

        expect(result).to run_successfully
        expect(SiteSetting.enable_form_templates).to eq(true)
        expect(SiteSetting.about_page_extra_groups).to eq("")
      end
    end

    context "when a linked audience is submitted through the toggle" do
      let(:params) { super().merge(group_names: ["staff"]) }

      before do
        mock_upcoming_change_metadata(
          enable_form_templates: {
            status: :experimental,
            group_setting: :about_page_extra_groups,
          },
        )
        SiteSetting.enable_form_templates = false
      end

      it "requires the dedicated audience update instead" do
        expect(result).to fail_a_policy(:allowed_enabled_for_target)
        expect(SiteSetting.enable_form_templates).to eq(false)
        expect(SiteSetting.about_page_extra_groups).to eq("")
      end
    end

    context "when everything's ok" do
      it { is_expected.to run_successfully }

      context "when allow_enabled_for restricts to [everyone]" do
        before do
          mock_upcoming_change_metadata(
            enable_form_templates: {
              impact: "feature,all_members",
              status: :experimental,
              impact_type: "feature",
              impact_role: "all_members",
              allow_enabled_for: [:everyone],
            },
          )
        end

        context "when toggling on with existing groups" do
          let(:enabled) { true }

          fab!(:site_setting_group) do
            Fabricate(:site_setting_group, name: "enable_form_templates", group_ids: "1|2")
          end

          before { SiteSetting.enable_form_templates = false }

          it "clears the SiteSettingGroup record" do
            expect { result }.to change {
              SiteSettingGroup.where(name: "enable_form_templates").count
            }.from(1).to(0)
          end
        end

        context "when toggling off with existing groups" do
          let(:enabled) { false }

          fab!(:site_setting_group) do
            Fabricate(:site_setting_group, name: "enable_form_templates", group_ids: "1|2")
          end

          before { SiteSetting.enable_form_templates = true }

          it "clears the SiteSettingGroup record" do
            expect { result }.to change {
              SiteSettingGroup.where(name: "enable_form_templates").count
            }.from(1).to(0)
          end
        end

        context "when toggling on with no existing groups" do
          let(:enabled) { true }

          before { SiteSetting.enable_form_templates = false }

          it { is_expected.to run_successfully }
        end
      end

      context "when allow_enabled_for is [staff, specific_groups]" do
        before do
          mock_upcoming_change_metadata(
            enable_form_templates: {
              impact: "feature,all_members",
              status: :experimental,
              impact_type: "feature",
              impact_role: "all_members",
              allow_enabled_for: %i[staff specific_groups],
            },
          )
          SiteSetting.enable_form_templates = false
        end

        context "when toggling on with no existing groups (target would be everyone)" do
          let(:enabled) { true }

          it { is_expected.to fail_a_policy(:allowed_enabled_for_target) }
        end

        context "when toggling on with existing groups configured" do
          let(:enabled) { true }

          fab!(:site_setting_group) do
            Fabricate(:site_setting_group, name: "enable_form_templates", group_ids: "1|3")
          end

          it { is_expected.to run_successfully }

          it "preserves the SiteSettingGroup record" do
            expect { result }.not_to change {
              SiteSettingGroup.where(name: "enable_form_templates").count
            }
          end
        end

        context "when toggling off" do
          let(:enabled) { false }

          it { is_expected.to run_successfully }
        end
      end

      context "when allow_enabled_for is omitted" do
        let(:enabled) { true }

        before { SiteSetting.enable_form_templates = false }

        it { is_expected.to run_successfully }
      end

      context "when log_change is true" do
        let(:options) { { log_change: true } }

        context "when enabling the setting" do
          let(:enabled) { true }

          before { SiteSetting.enable_form_templates = false }

          it "enables the specified setting" do
            expect { result }.to change { SiteSetting.enable_form_templates }.to(true)
          end

          it "creates an entry in the staff action logs with correct context" do
            expect { result }.to change {
              UserHistory.where(
                action: UserHistory.actions[:upcoming_change_toggled],
                subject: "enable_form_templates",
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
                upcoming_change_name: "enable_form_templates",
              ).count
            }.by(1)
          end

          it "triggers the upcoming_change_enabled event" do
            events =
              DiscourseEvent
                .track_events { result }
                .select { |e| e[:event_name] == :upcoming_change_enabled }

            expect(events.first[:params]).to eq([setting_name])
          end
        end

        context "when disabling the setting" do
          let(:enabled) { false }

          before { SiteSetting.enable_form_templates = true }

          it "disables the specified setting" do
            expect { result }.to change { SiteSetting.enable_form_templates }.to(false)
          end

          it "creates an entry in the staff action logs with correct context" do
            expect { result }.to change {
              UserHistory.where(
                action: UserHistory.actions[:upcoming_change_toggled],
                subject: "enable_form_templates",
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
                upcoming_change_name: "enable_form_templates",
              ).count
            }.by(1)
          end

          it "triggers the upcoming_change_disabled event" do
            events =
              DiscourseEvent
                .track_events { result }
                .select { |e| e[:event_name] == :upcoming_change_disabled }

            expect(events.first[:params]).to eq([setting_name])
          end
        end
      end

      context "when log_change is false" do
        let(:options) { { log_change: false } }

        context "when enabling the setting" do
          let(:enabled) { true }

          before { SiteSetting.enable_form_templates = false }

          it "enables the specified setting" do
            expect { result }.to change { SiteSetting.enable_form_templates }.to(true)
          end

          it "does not create an entry in the staff action logs" do
            expect { result }.not_to change {
              UserHistory.where(
                action: UserHistory.actions[:upcoming_change_toggled],
                subject: "enable_form_templates",
              ).count
            }
          end

          it "does not create an UpcomingChangeEvent" do
            expect { result }.not_to change { UpcomingChangeEvent.count }
          end

          it "triggers the upcoming_change_enabled event" do
            events =
              DiscourseEvent
                .track_events { result }
                .select { |e| e[:event_name] == :upcoming_change_enabled }

            expect(events.first[:params]).to eq([setting_name])
          end
        end

        context "when disabling the setting" do
          let(:enabled) { false }

          before { SiteSetting.enable_form_templates = true }

          it "disables the specified setting" do
            expect { result }.to change { SiteSetting.enable_form_templates }.to(false)
          end

          it "does not create an entry in the staff action logs" do
            expect { result }.not_to change {
              UserHistory.where(
                action: UserHistory.actions[:upcoming_change_toggled],
                subject: "enable_form_templates",
              ).count
            }
          end

          it "does not create an UpcomingChangeEvent" do
            expect { result }.not_to change { UpcomingChangeEvent.count }
          end

          it "triggers the upcoming_change_disabled event" do
            events =
              DiscourseEvent
                .track_events { result }
                .select { |e| e[:event_name] == :upcoming_change_disabled }

            expect(events.first[:params]).to eq([setting_name])
          end
        end
      end
    end
  end
end
