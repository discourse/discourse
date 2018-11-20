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
      before do
        @change_site_setting = UserHistory.create!(action: UserHistory.actions[:change_site_setting], subject: "title", previous_value: "Old", new_value: "New")
        @change_trust_level  = UserHistory.create!(action: UserHistory.actions[:change_trust_level], target_user_id: Fabricate(:user).id, details: "stuff happened")
      end

      it "returns all records for admins" do
        records = described_class.staff_action_records(Fabricate(:admin)).to_a
        expect(records.size).to eq(2)
      end

      it "doesn't return records to moderators that only admins should see" do
        records = described_class.staff_action_records(Fabricate(:moderator)).to_a
        expect(records).to eq([@change_trust_level])
      end
    end
  end

end
