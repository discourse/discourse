# frozen_string_literal: true

RSpec.describe UserBadge do
  fab!(:badge)
  fab!(:user)

  describe "Validations" do
    let(:subject) { BadgeGranter.grant(badge, user) }

    it { is_expected.to validate_presence_of(:badge_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:granted_at) }
    it { is_expected.to validate_presence_of(:granted_by) }
    it { is_expected.to validate_uniqueness_of(:badge_id).scoped_to(:user_id) }
  end

  describe "#save" do
    it "triggers the 'user_badge_granted' DiscourseEvent" do
      user_badge =
        UserBadge.new(
          badge: badge,
          user: user,
          granted_at: Time.zone.now,
          granted_by: Discourse.system_user,
        )

      event =
        DiscourseEvent.track(:user_badge_granted, args: [badge.id, user.id]) { user_badge.save! }

      expect(event).to be_present
    end
  end

  describe "#destroy" do
    it "triggers the 'user_badge_revoked' DiscourseEvent" do
      user_badge =
        UserBadge.create(
          badge: badge,
          user: user,
          granted_at: Time.zone.now,
          granted_by: Discourse.system_user,
        )

      event = DiscourseEvent.track(:user_badge_revoked) { user_badge.destroy! }

      expect(event).to be_present
    end
  end

  describe "featured rank" do
    fab!(:user)
    fab!(:user_2) { Fabricate(:user) }
    fab!(:user_badge_tl1) do
      UserBadge.create!(
        badge_id: Badge::BasicUser,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_tl2) do
      UserBadge.create!(
        badge_id: Badge::Member,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_wiki) do
      UserBadge.create!(
        badge_id: Badge::WikiEditor,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end
    fab!(:user_badge_like) do
      UserBadge.create!(
        badge_id: Badge::FirstLike,
        user: user,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    fab!(:user_2_badge_tl1) do
      UserBadge.create!(
        badge_id: Badge::BasicUser,
        user: user_2,
        granted_by: Discourse.system_user,
        granted_at: Time.now,
      )
    end

    it "gives user badges the correct rank" do
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_badge_wiki.reload.featured_rank).to eq(2)
      expect(user_badge_like.reload.featured_rank).to eq(3)
      expect(user_badge_tl1.reload.featured_rank).to eq(4) # Previous trust level badges last
    end

    it "gives duplicate user_badges the same rank" do
      ub1 =
        UserBadge.create!(
          badge_id: Badge::GreatTopic,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
        )
      ub2 =
        UserBadge.create!(
          badge_id: Badge::GreatTopic,
          user: user,
          granted_by: Discourse.system_user,
          granted_at: Time.now,
          seq: 1,
        )

      expect(ub1.reload.featured_rank).to eq(2)
      expect(ub2.reload.featured_rank).to eq(2)
    end

    it "skips disabled badges" do
      user_badge_wiki.badge.update(enabled: false)
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_badge_like.reload.featured_rank).to eq(2)
      expect(user_badge_tl1.reload.featured_rank).to eq(3) # Previous trust level badges last
      expect(user_badge_wiki.reload.featured_rank).to eq(4) # Disabled
    end

    it "can ensure consistency per user" do
      user_badge_tl2.update_column(:featured_rank, 20) # Update without hooks
      expect(user_badge_tl2.reload.featured_rank).to eq(20) # Double check
      user_2_badge_tl1.update_column(:featured_rank, 20) # Update without hooks
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20) # Double check

      UserBadge.update_featured_ranks!([user.id])

      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20)
    end

    it "can ensure consistency for all users" do
      user_badge_tl2.update_column(:featured_rank, 20) # Update without hooks
      expect(user_badge_tl2.reload.featured_rank).to eq(20) # Double check
      user_2_badge_tl1.update_column(:featured_rank, 20) # Update without hooks
      expect(user_2_badge_tl1.reload.featured_rank).to eq(20) # Double check

      UserBadge.update_featured_ranks!

      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_2_badge_tl1.reload.featured_rank).to eq(1)
    end
  end
end
