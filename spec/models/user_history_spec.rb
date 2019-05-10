# frozen_string_literal: true

require 'rails_helper'

describe UserHistory do

  describe '#actions' do
    context "verify enum sequence" do
      before do
        @actions = UserHistory.actions
      end

      it "'delete_user' should be at 1st position" do
        expect(@actions[:delete_user]).to eq(1)
      end

      it "'change_site_text' should be at 29th position" do
        expect(@actions[:change_site_text]).to eq(29)
      end
    end
  end

  describe '#staff_action_records' do
    context "with some records" do
      fab!(:admin) { Fabricate(:admin) }
      let(:custom_type) { 'confirmed_ham' }

      before do
        @change_site_setting = UserHistory.create!(action: UserHistory.actions[:change_site_setting], subject: "title", previous_value: "Old", new_value: "New")
        @change_trust_level  = UserHistory.create!(action: UserHistory.actions[:change_trust_level], target_user_id: Fabricate(:user).id, details: "stuff happened")
        @custom_history = StaffActionLogger.new(admin).log_custom('confirmed_ham', admin_only: true)
      end

      it "returns all records for admins" do
        records = described_class.staff_action_records(admin).to_a
        expect(records.size).to eq(3)
      end

      it "doesn't return records to moderators that only admins should see" do
        records = described_class.staff_action_records(Fabricate(:moderator)).to_a
        expect(records).not_to include([@change_site_setting])
      end

      it 'filters by action' do
        records = described_class.staff_action_records(admin, action_id: @change_site_setting.action_before_type_cast).to_a
        expect(records.size).to eq(1)
        expect(records.first).to eq(@change_site_setting)
      end

      it 'filters by action_name' do
        records = described_class.staff_action_records(admin, action_name: "change_site_setting").to_a
        expect(records.size).to eq(1)
        expect(records.first).to eq(@change_site_setting)
      end

      it 'Uses action_name as custom_type when searching for custom_staff logs' do
        records = described_class.staff_action_records(
          admin, action_name: custom_type, action_id: described_class.actions[:custom_staff]
        ).to_a

        expect(records.size).to eq(1)
        expect(records.first).to eq(@custom_history)
      end
    end
  end
end
