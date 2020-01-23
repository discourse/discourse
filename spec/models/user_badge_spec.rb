# frozen_string_literal: true

require 'rails_helper'

describe UserBadge do

  context 'validations' do
    fab!(:badge) { Fabricate(:badge) }
    fab!(:user) { Fabricate(:user) }
    let(:subject) { BadgeGranter.grant(badge, user) }

    it { is_expected.to validate_presence_of(:badge_id) }
    it { is_expected.to validate_presence_of(:user_id) }
    it { is_expected.to validate_presence_of(:granted_at) }
    it { is_expected.to validate_presence_of(:granted_by) }
    it { is_expected.to validate_uniqueness_of(:badge_id).scoped_to(:user_id) }
  end

  describe "featured rank" do
    fab!(:user) { Fabricate(:user) }
    fab!(:user_badge_tl1) { UserBadge.create!(badge_id: Badge::BasicUser, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }
    fab!(:user_badge_tl2) { UserBadge.create!(badge_id: Badge::Member, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }
    fab!(:user_badge_wiki) { UserBadge.create!(badge_id: Badge::WikiEditor, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }
    fab!(:user_badge_like) { UserBadge.create!(badge_id: Badge::FirstLike, user: user, granted_by: Discourse.system_user, granted_at: Time.now) }

    it "gives user badges the correct rank" do
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
      expect(user_badge_wiki.reload.featured_rank).to eq(2)
      expect(user_badge_like.reload.featured_rank).to eq(3)
      expect(user_badge_tl1.reload.featured_rank).to eq(4) # Previous trust level badges last
    end

    it "gives duplicate user_badges the same rank" do
      ub1 = UserBadge.create!(badge_id: Badge::GreatTopic, user: user, granted_by: Discourse.system_user, granted_at: Time.now)
      ub2 = UserBadge.create!(badge_id: Badge::GreatTopic, user: user, granted_by: Discourse.system_user, granted_at: Time.now, seq: 1)

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
      UserBadge.update_featured_ranks! user.id
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
    end

    it "can ensure consistency for all users" do
      user_badge_tl2.update_column(:featured_rank, 20) # Update without hooks
      expect(user_badge_tl2.reload.featured_rank).to eq(20) # Double check
      UserBadge.update_featured_ranks!
      expect(user_badge_tl2.reload.featured_rank).to eq(1)
    end

  end

end
