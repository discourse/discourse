# frozen_string_literal: true

RSpec.describe UpcomingChanges::UpdateGroups do
  describe described_class::Contract, type: :model do
    it { is_expected.to validate_presence_of :setting }
    it { is_expected.to validate_presence_of :group_names }
  end

  describe ".call" do
    subject(:result) { described_class.call(params:, **dependencies) }

    fab!(:acting_user, :admin)

    let(:params) { { setting:, group_names: } }
    let(:dependencies) { { guardian: acting_user.guardian } }
    let(:setting) { "enable_upload_debug_mode" }
    let(:group_names) { %w[staff trust_level_2] }
    let(:group_setting) { :about_page_extra_groups }

    before do
      mock_upcoming_change_metadata(
        enable_upload_debug_mode: {
          status: :experimental,
          group_setting:,
        },
      )
      SiteSetting.enable_upload_debug_mode = false
    end

    context "when the audience is empty" do
      let(:group_names) { [] }

      it { is_expected.to fail_a_contract }
    end

    context "when a member changes the audience" do
      fab!(:acting_user, :user)

      it { is_expected.to fail_a_policy(:current_user_is_admin) }
    end

    context "when the flag does not exist" do
      let(:setting) { "missing_upcoming_change" }

      it { is_expected.to fail_a_policy(:setting_is_available) }
    end

    context "when the change has no linked group setting" do
      before { mock_upcoming_change_metadata(enable_upload_debug_mode: { status: :experimental }) }

      it { is_expected.to fail_to_find_a_model(:group_setting) }
    end

    context "when the metadata names a non-group setting" do
      let(:group_setting) { :title }

      it { is_expected.to fail_to_find_a_model(:group_setting) }
    end

    context "when a supplied group does not exist" do
      let(:group_names) { %w[staff missing_group] }

      it "rejects the complete audience without saving its valid subset" do
        expect(result).to fail_to_find_a_model(:group_ids)
        expect(SiteSetting.about_page_extra_groups).to eq("")
      end
    end

    context "when the audience includes a disallowed group" do
      let(:group_names) { %w[staff anonymous_users] }

      it "preserves the audience and flag" do
        expect(result).to fail_a_policy(:groups_are_allowed)
        expect(SiteSetting.about_page_extra_groups).to eq("")
        expect(SiteSetting.enable_upload_debug_mode).to eq(false)
      end
    end

    context "when the site setting updater rejects the change" do
      before { SiteSetting.stubs(:shadowed_settings).returns(Set[:about_page_extra_groups]) }

      it "reports the failure without saving the audience" do
        expect(result).to fail_a_step(:update_setting)
        expect(SiteSetting.about_page_extra_groups).to eq("")
        expect(SiteSetting.enable_upload_debug_mode).to eq(false)
      end
    end

    context "when the linked setting has mandatory groups" do
      let(:group_setting) { :hidden_post_visible_groups }
      let(:group_names) { ["trust_level_2"] }

      it "returns the canonical audience including mandatory groups" do
        expect(result).to run_successfully
        expect(SiteSetting.hidden_post_visible_groups).to eq("1|2|12")
        expect(result.groups.split(",")).to contain_exactly("admins", "moderators", "trust_level_2")
        expect(result.group_setting).to include(
          setting: :hidden_post_visible_groups,
          value: "1|2|12",
          mandatory_values: "1|2",
          disallowed_groups: "4",
        )
      end
    end

    context "when the audience is valid" do
      it "updates the linked setting independently of the flag without creating another audience" do
        expect(result).to run_successfully
        expect(SiteSetting.about_page_extra_groups.split("|")).to contain_exactly("3", "12")
        expect(SiteSetting.enable_upload_debug_mode).to eq(false)
        expect(SiteSettingGroup.where(name: setting)).to be_empty
        expect(result.groups.split(",")).to contain_exactly("staff", "trust_level_2")
        expect(result.group_setting).to include(
          setting: group_setting,
          value: SiteSetting.about_page_extra_groups,
        )
      end

      it "logs the actual group site setting update" do
        expect { result }.to change {
          UserHistory.where(
            action: UserHistory.actions[:change_site_setting],
            subject: group_setting.to_s,
          ).count
        }.by(1)
      end
    end
  end
end
