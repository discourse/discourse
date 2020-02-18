# frozen_string_literal: true

require 'rails_helper'

describe Jobs::MassAwardBadge do
  describe '#execute' do
    fab!(:badge) { Fabricate(:badge) }
    fab!(:user) { Fabricate(:user) }
    let(:email_mode) { 'email' }

    it 'creates the badge for an existing user' do
      execute_job([user.email])

      expect(UserBadge.where(user: user, badge: badge).exists?).to eq(true)
    end

    it 'works with multiple users' do
      user_2 = Fabricate(:user)

      execute_job([user.email, user_2.email])

      expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
      expect(UserBadge.exists?(user: user_2, badge: badge)).to eq(true)
    end

    it 'also creates a notification for the user' do
      execute_job([user.email])

      expect(Notification.exists?(user: user)).to eq(true)
      expect(UserBadge.where.not(notification_id: nil).exists?(user: user, badge: badge)).to eq(true)
    end

    it 'updates badge ranks correctly' do
      user_2 = Fabricate(:user)

      UserBadge.create!(badge_id: Badge::Member, user: user, granted_by: Discourse.system_user, granted_at: Time.now)

      execute_job([user.email, user_2.email])

      expect(UserBadge.find_by(user: user, badge: badge).featured_rank).to eq(2)
      expect(UserBadge.find_by(user: user_2, badge: badge).featured_rank).to eq(1)
    end

    def execute_job(emails)
      subject.execute(users_batch: emails, badge_id:  badge.id, mode: 'email')
    end
  end
end
