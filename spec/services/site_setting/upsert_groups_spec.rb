# frozen_string_literal: true

RSpec.describe SiteSetting::UpsertGroups do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :group_names }
    it { is_expected.to validate_presence_of :setting }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:admin)

    let(:params) { { group_names:, setting: } }
    let(:dependencies) { { guardian: } }
    let(:group_names) { %w[trust_level_0 admins] }
    let(:setting) { "enable_upload_debug_mode" }
    let(:guardian) { admin.guardian }

    context "when group_names is blank" do
      let(:group_names) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when setting is blank" do
      let(:setting) { nil }

      it { is_expected.to fail_a_contract }
    end

    context "when group names don't match any existing groups" do
      let(:group_names) { ["nonexistent_group"] }

      it { is_expected.to fail_to_find_a_model(:group_ids) }
    end

    context "when group_names is an empty array" do
      let(:group_names) { [] }

      it { is_expected.to fail_a_contract }
    end

    context "when some group names exist and some don't" do
      let(:group_names) { %w[trust_level_0 nonexistent_group admins] }

      it { is_expected.to run_successfully }

      it "only includes the existing groups" do
        result
        site_setting_group = SiteSettingGroup.find_by(name: setting)
        expect(site_setting_group.group_ids).to eq("10|1")
      end
    end

    context "when a non-admin user tries to upsert groups" do
      let(:guardian) { Guardian.new }

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when an admin user upserts groups for a setting" do
      it { is_expected.to run_successfully }

      it "creates a new site setting group record" do
        expect { result }.to change { SiteSettingGroup.count }.by(1)
      end

      it "stores the group ids in pipe-delimited format" do
        result
        site_setting_group = SiteSettingGroup.find_by(name: setting)
        expect(site_setting_group.group_ids).to eq("10|1")
      end

      it "creates an entry in the staff action logs" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting_groups],
            subject: setting,
          ).count
        }.by(1)

        history = UserHistory.where(subject: setting).last
        expect(history.previous_value).to be_nil
        expect(history.new_value).to eq("10|1")
      end

      it "notifies that site settings have changed" do
        SiteSetting.expects(:notify_changed!).once
        result
      end

      it "refreshes the site setting group ids for this process" do
        SiteSetting.expects(:refresh_site_setting_group_ids!).once
        result
      end
    end

    context "when an admin user updates groups for an existing setting" do
      before { SiteSettingGroup.create!(name: setting, group_ids: "10|13") }

      let(:group_names) { %w[admins trust_level_3] }

      it { is_expected.to run_successfully }

      it "does not create a new record" do
        expect { result }.not_to change { SiteSettingGroup.count }
      end

      it "updates the existing site setting group record" do
        expect { result }.to change { SiteSettingGroup.find_by(name: setting).group_ids }.from(
          "10|13",
        ).to("13|1")
      end

      it "creates an entry in the staff action logs with previous value" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting_groups],
            subject: setting,
          ).count
        }.by(1)

        history = UserHistory.where(subject: setting).last
        expect(history.previous_value).to eq("10|13")
        expect(history.new_value).to eq("13|1")
      end

      it "notifies that site settings have changed" do
        SiteSetting.expects(:notify_changed!).once
        result
      end

      context "when group_names are empty" do
        let(:group_names) { [] }

        it "deletes the existing site setting group record" do
          expect { result }.to change { SiteSettingGroup.where(name: setting).count }.by(-1)
        end

        it "refreshes the site setting group ids for this process" do
          SiteSetting.expects(:refresh_site_setting_group_ids!).once
          result
        end
      end
    end
  end
end
