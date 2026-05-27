# frozen_string_literal: true

RSpec.describe UserHistory do
  describe "#actions" do
    context "when verifying enum sequence" do
      let!(:actions) { described_class.actions }

      it "'delete_user' should be at 1st position" do
        expect(actions[:delete_user]).to eq(1)
      end

      it "'change_site_text' should be at 29th position" do
        expect(actions[:change_site_text]).to eq(29)
      end
    end
  end

  describe "#staff_action_records" do
    context "with some records" do
      fab!(:admin)

      let(:custom_type) { "confirmed_ham" }
      let!(:change_site_setting) do
        UserHistory.create!(
          action: UserHistory.actions[:change_site_setting],
          subject: "title",
          previous_value: "Old",
          new_value: "New",
        )
      end
      let!(:change_trust_level) do
        UserHistory.create!(
          action: UserHistory.actions[:change_trust_level],
          target_user_id: Fabricate(:user).id,
          details: "stuff happened",
        )
      end
      let!(:custom_history) do
        StaffActionLogger.new(admin).log_custom("confirmed_ham", admin_only: true)
      end

      it "returns all records for admins" do
        records = described_class.staff_action_records(admin).to_a
        expect(records.size).to eq(3)
      end

      it "only returns moderator-visible actions to moderators (allowlist approach)" do
        records = described_class.staff_action_records(Fabricate(:moderator)).to_a
        expect(records).to contain_exactly(change_trust_level)
        expect(records).not_to include(change_site_setting, custom_history)
      end

      it "filters by action" do
        records =
          described_class.staff_action_records(
            admin,
            action_id: change_site_setting.action_before_type_cast,
          ).to_a
        expect(records.size).to eq(1)
        expect(records.first).to eq(change_site_setting)
      end

      it "filters by action_name" do
        records =
          described_class.staff_action_records(admin, action_name: "change_site_setting").to_a
        expect(records.size).to eq(1)
        expect(records.first).to eq(change_site_setting)
      end

      it "Uses action_name as custom_type when searching for custom_staff logs" do
        records =
          described_class.staff_action_records(
            admin,
            action_name: custom_type,
            action_id: described_class.actions[:custom_staff],
          ).to_a

        expect(records.size).to eq(1)
        expect(records.first).to eq(custom_history)
      end

      it "filters by start and/or end date" do
        freeze_time

        10.times do |i|
          Fabricate(
            :user_history,
            action: UserHistory.actions[:suspend_user],
            created_at: i.days.ago,
          )
        end

        records =
          described_class.staff_action_records(admin, start_date: 7.days.ago, end_date: 2.days.ago)

        expect(records.size).to eq(7 - 2 + 1)
      end
    end
  end

  describe ".site_setting_excluded_actions" do
    it "excludes category actions when moderators_manage_categories is disabled" do
      SiteSetting.moderators_manage_categories = false
      expect(described_class.site_setting_excluded_actions).to include(
        :create_category,
        :change_category_settings,
        :delete_category,
      )
    end

    it "includes category actions when moderators_manage_categories is enabled" do
      SiteSetting.moderators_manage_categories = true
      expect(described_class.site_setting_excluded_actions).not_to include(
        :create_category,
        :change_category_settings,
        :delete_category,
      )
    end

    it "excludes trust level actions when moderators_change_trust_levels is disabled" do
      SiteSetting.moderators_change_trust_levels = false
      expect(described_class.site_setting_excluded_actions).to include(
        :change_trust_level,
        :lock_trust_level,
        :unlock_trust_level,
      )
    end

    it "includes trust level actions when moderators_change_trust_levels is enabled" do
      SiteSetting.moderators_change_trust_levels = true
      expect(described_class.site_setting_excluded_actions).not_to include(
        :change_trust_level,
        :lock_trust_level,
        :unlock_trust_level,
      )
    end

    it "excludes email actions when moderators_view_emails is disabled" do
      SiteSetting.moderators_view_emails = false
      expect(described_class.site_setting_excluded_actions).to include(
        :check_email,
        :add_email,
        :update_email,
        :destroy_email,
      )
    end

    it "includes email actions when moderators_view_emails is enabled" do
      SiteSetting.moderators_view_emails = true
      expect(described_class.site_setting_excluded_actions).not_to include(
        :check_email,
        :add_email,
        :update_email,
        :destroy_email,
      )
    end
  end

  describe ".moderator_visible_action_ids" do
    it "returns action IDs for moderator-visible actions" do
      ids = described_class.moderator_visible_action_ids
      expect(ids).to include(described_class.actions[:suspend_user])
      expect(ids).to include(described_class.actions[:delete_topic])
      expect(ids).not_to include(described_class.actions[:change_site_setting])
    end

    it "responds dynamically to site setting changes" do
      SiteSetting.moderators_manage_categories = true
      expect(described_class.moderator_visible_action_ids).to include(
        described_class.actions[:create_category],
      )

      SiteSetting.moderators_manage_categories = false
      expect(described_class.moderator_visible_action_ids).not_to include(
        described_class.actions[:create_category],
      )
    end
  end
end
