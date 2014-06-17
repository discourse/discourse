require 'spec_helper'

describe BadgeGranter do

  let(:badge) { Fabricate(:badge) }
  let(:user) { Fabricate(:user) }

  before do
    SiteSetting.enable_badges = true
  end

  describe 'grant' do

    it 'grants a badge' do
      user_badge = BadgeGranter.grant(badge, user)
      user_badge.should be_present
    end

    it 'sets granted_at' do
      time = Time.zone.now
      Timecop.freeze time

      user_badge = BadgeGranter.grant(badge, user)
      user_badge.granted_at.should eq(time)

      Timecop.return
    end

    it 'sets granted_by if the option is present' do
      admin = Fabricate(:admin)
      StaffActionLogger.any_instance.expects(:log_badge_grant).once
      user_badge = BadgeGranter.grant(badge, user, granted_by: admin)
      user_badge.granted_by.should eq(admin)
    end

    it 'defaults granted_by to the system user' do
      StaffActionLogger.any_instance.expects(:log_badge_grant).never
      user_badge = BadgeGranter.grant(badge, user)
      user_badge.granted_by_id.should eq(Discourse.system_user.id)
    end

    it 'does not allow a regular user to grant badges' do
      user_badge = BadgeGranter.grant(badge, user, granted_by: Fabricate(:user))
      user_badge.should_not be_present
    end

    it 'increments grant_count on the badge and creates a notification' do
      BadgeGranter.grant(badge, user)
      badge.reload.grant_count.should eq(1)
      user.notifications.find_by(notification_type: Notification.types[:granted_badge]).data_hash["badge_id"].should == badge.id
    end

  end

  describe 'revoke' do

    let(:admin) { Fabricate(:admin) }
    let!(:user_badge) { BadgeGranter.grant(badge, user) }

    it 'revokes the badge and does necessary cleanup' do
      user.title = badge.name; user.save!
      badge.reload.grant_count.should eq(1)
      StaffActionLogger.any_instance.expects(:log_badge_revoke).with(user_badge)
      BadgeGranter.revoke(user_badge, revoked_by: admin)
      UserBadge.find_by(user: user, badge: badge).should_not be_present
      badge.reload.grant_count.should eq(0)
      user.notifications.where(notification_type: Notification.types[:granted_badge]).should be_empty
      user.reload.title.should == nil
    end

  end

  context "update_badges" do
    let(:user) { Fabricate(:user) }
    let(:liker) { Fabricate(:user) }

    it "grants and revokes trust level badges" do
      user.change_trust_level!(:elder)
      UserBadge.where(user_id: user.id, badge_id: Badge.trust_level_badge_ids).count.should eq(4)
      user.change_trust_level!(:basic)
      UserBadge.where(user_id: user.id, badge_id: 1).first.should_not be_nil
      UserBadge.where(user_id: user.id, badge_id: 2).first.should be_nil
    end

    it "grants system like badges" do
      post = create_post(user: user)
      # Welcome badge
      PostAction.act(liker, post, PostActionType.types[:like])
      UserBadge.find_by(user_id: user.id, badge_id: 5).should_not be_nil
      # Nice post badge
      post.update_attributes like_count: 10
      BadgeGranter.update_badges(action: :post_like, post_id: post.id)
      UserBadge.find_by(user_id: user.id, badge_id: 6).should_not be_nil
      # Good post badge
      post.update_attributes like_count: 25
      BadgeGranter.update_badges(action: :post_like, post_id: post.id)
      UserBadge.find_by(user_id: user.id, badge_id: 7).should_not be_nil
      # Great post badge
      post.update_attributes like_count: 100
      BadgeGranter.update_badges(action: :post_like, post_id: post.id)
      UserBadge.find_by(user_id: user.id, badge_id: 8).should_not be_nil
      # Revoke badges on unlike
      post.update_attributes like_count: 99
      BadgeGranter.update_badges(action: :post_like, post_id: post.id)
      UserBadge.find_by(user_id: user.id, badge_id: 8).should be_nil
    end
  end

end
