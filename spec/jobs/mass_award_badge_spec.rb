# frozen_string_literal: true

require 'rails_helper'

describe Jobs::MassAwardBadge do
  describe '#execute' do
    fab!(:badge) { Fabricate(:badge) }
    fab!(:user) { Fabricate(:user) }

    it 'creates the badge for an existing user' do
      subject.execute(user_emails: [user.email], badge_id:  badge.id)

      expect(UserBadge.where(user: user, badge: badge).exists?).to eq(true)
    end

    it 'works with multiple users' do
      user_2 = Fabricate(:user)

      subject.execute(user_emails: [user.email, user_2.email], badge_id:  badge.id)

      expect(UserBadge.exists?(user: user, badge: badge)).to eq(true)
      expect(UserBadge.exists?(user: user_2, badge: badge)).to eq(true)
    end

    it 'also creates a notification for the user' do
      subject.execute(user_emails: [user.email], badge_id:  badge.id)

      expect(Notification.exists?(user: user)).to eq(true)
      expect(UserBadge.where.not(notification_id: nil).exists?(user: user, badge: badge)).to eq(true)
    end

    it 'updates badge ranks correctly' do
      user_2 = Fabricate(:user)

      UserBadge.create!(badge_id: Badge::Member, user: user, granted_by: Discourse.system_user, granted_at: Time.now)

      subject.execute(user_emails: [user.email, user_2.email], badge_id:  badge.id)

      expect(UserBadge.find_by(user: user, badge: badge).featured_rank).to eq(2)
      expect(UserBadge.find_by(user: user_2, badge: badge).featured_rank).to eq(1)
    end
  end
end
