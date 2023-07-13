# frozen_string_literal: true

RSpec.describe Jobs::MassAwardBadge do
  describe "#execute" do
    fab!(:badge) { Fabricate(:badge) }
    fab!(:user) { Fabricate(:user) }
    let(:email_mode) { "email" }

    it "creates the badge for an existing user" do
      execute_job(user)

      expect(UserBadge.where(user: user, badge: badge).exists?).to eq(true)
    end

    it "also creates a notification for the user" do
      execute_job(user)

      expect(Notification.exists?(user: user)).to eq(true)
      expect(UserBadge.where.not(notification_id: nil).exists?(user: user, badge: badge)).to eq(
        true,
      )
    end

    it "updates badge ranks correctly" do
      user_2 = Fabricate(:user)

      UserBadge.create!(
        badge_id: Badge::Member,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )

      execute_job(user)
      execute_job(user_2)

      expect(UserBadge.find_by(user: user, badge: badge).featured_rank).to eq(2)
      expect(UserBadge.find_by(user: user_2, badge: badge).featured_rank).to eq(1)
    end

    it "grants a badge multiple times to a user" do
      badge.update!(multiple_grant: true)
      Notification.destroy_all
      execute_job(user, count: 4, grant_existing_holders: true)
      instances = UserBadge.where(user: user, badge: badge)
      expect(instances.count).to eq(4)
      expect(instances.pluck(:seq).sort).to eq((0...4).to_a)
      notifications = Notification.where(user: user)
      expect(notifications.count).to eq(1)
      expect(instances.map(&:notification_id).uniq).to contain_exactly(notifications.first.id)
    end

    def execute_job(user, count: 1, grant_existing_holders: false)
      subject.execute(
        user: user.id,
        badge: badge.id,
        count: count,
        grant_existing_holders: grant_existing_holders,
      )
    end
  end
end
