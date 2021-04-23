# frozen_string_literal: true

require 'rails_helper'

describe 'Setting changes' do
  describe '#must_approve_users' do
    before { SiteSetting.must_approve_users = false }

    it 'does not approve a user with associated reviewables' do
      user_pending_approval = Fabricate(:reviewable_user).target

      SiteSetting.must_approve_users = true

      expect(user_pending_approval.reload.approved?).to eq(false)
    end

    it 'approves a user with no associated reviewables' do
      non_approved_user = Fabricate(:user, approved: false)

      SiteSetting.must_approve_users = true

      expect(non_approved_user.reload.approved?).to eq(true)
    end
  end

  describe '#reviewable_low_priority_threshold' do
    let(:new_threshold) { 5 }

    it 'sets the low priority value' do
      medium_threshold = 10
      Reviewable.set_priorities(medium: medium_threshold)

      expect(Reviewable.min_score_for_priority(:low)).not_to eq(new_threshold)

      SiteSetting.reviewable_low_priority_threshold = new_threshold

      expect(Reviewable.min_score_for_priority(:low)).to eq(new_threshold)
    end

    it "does nothing if the other thresholds were not calculated" do
      Reviewable.set_priorities(medium: 0.0)

      SiteSetting.reviewable_low_priority_threshold = new_threshold

      expect(Reviewable.min_score_for_priority(:low)).not_to eq(new_threshold)
    end
  end
end
