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
end
