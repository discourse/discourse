require 'spec_helper'

describe BadgeGranter do

  let(:badge) { Fabricate(:badge) }
  let(:user) { Fabricate(:user) }

  describe 'revoke_titles' do
    it 'can correctly revoke titles' do
      badge = Fabricate(:badge, allow_title: true)
      user = Fabricate(:user, title: badge.name)
      user.reload

      user.user_profile.update_column(:badge_granted_title, true)

      BadgeGranter.grant(badge, user)
      BadgeGranter.revoke_ungranted_titles!

      user.reload
      user.title.should == badge.name

      badge.update_column(:allow_title, false)
      BadgeGranter.revoke_ungranted_titles!

      user.reload
      user.title.should == ''

      user.title = "CEO"
      user.save

      BadgeGranter.revoke_ungranted_titles!

      user.reload
      user.title.should == "CEO"
    end
  end

  describe 'preview' do
    it 'can correctly preview' do
      Fabricate(:user, email: 'sam@gmail.com')
      result = BadgeGranter.preview('select id user_id, null post_id, created_at granted_at from users where email like \'%gmail.com\'')
      result[:grant_count].should == 1
    end
  end

  describe 'backfill' do

    it 'has no broken badge queries' do
      Badge.all.each do |b|
        BadgeGranter.backfill(b)
      end
    end

    it 'can backfill the welcome badge' do
      post = Fabricate(:post)
      user2 = Fabricate(:user)
      PostAction.act(user2, post, PostActionType.types[:like])

      UserBadge.destroy_all
      BadgeGranter.backfill(Badge.find(Badge::Welcome))
      BadgeGranter.backfill(Badge.find(Badge::FirstLike))

      b = UserBadge.find_by(user_id: post.user_id)
      b.post_id.should == post.id
      b.badge_id = Badge::Welcome

      b = UserBadge.find_by(user_id: user2.id)
      b.post_id.should == post.id
      b.badge_id = Badge::FirstLike
    end

    it 'should grant missing badges' do
      post = Fabricate(:post, like_count: 30)
      2.times {
        BadgeGranter.backfill(Badge.find(Badge::NiceTopic), post_ids: [post.id])
        BadgeGranter.backfill(Badge.find(Badge::GoodTopic))
      }

      # TODO add welcome
      post.user.user_badges.pluck(:badge_id).sort.should == [Badge::NiceTopic,Badge::GoodTopic]

      post.user.notifications.count.should == 2

      Badge.find(Badge::NiceTopic).grant_count.should == 1
      Badge.find(Badge::GoodTopic).grant_count.should == 1
    end
  end

  describe 'grant' do

    it 'grants multiple badges' do
      badge = Fabricate(:badge, multiple_grant: true)
      user_badge = BadgeGranter.grant(badge, user)
      user_badge = BadgeGranter.grant(badge, user)
      user_badge.should be_present

      UserBadge.where(user_id: user.id).count.should == 2
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

    before do
      BadgeGranter.clear_queue!
    end

    it "grants autobiographer" do
      user.user_profile.bio_raw  = "THIS IS MY bio it a long bio I like my bio"
      user.uploaded_avatar_id = 10
      user.user_profile.save
      user.save

      BadgeGranter.process_queue!
      UserBadge.where(user_id: user.id, badge_id: Badge::Autobiographer).count.should eq(1)
    end

    it "grants read guidlines" do
      user.user_stat.read_faq = Time.now
      user.user_stat.save

      BadgeGranter.process_queue!
      UserBadge.where(user_id: user.id, badge_id: Badge::ReadGuidelines).count.should eq(1)
    end

    it "grants first link" do
      post = create_post
      post2 = create_post(raw: "#{Discourse.base_url}/t/slug/#{post.topic_id}")

      BadgeGranter.process_queue!
      UserBadge.where(user_id: post2.user.id, badge_id: Badge::FirstLink).count.should eq(1)
    end

    it "grants first edit" do
      SiteSetting.ninja_edit_window = 0
      post = create_post
      user = post.user

      UserBadge.where(user_id: user.id, badge_id: Badge::Editor).count.should eq(0)

      PostRevisor.new(post).revise!(user, { raw: "This is my new test 1235 123" })
      BadgeGranter.process_queue!

      UserBadge.where(user_id: user.id, badge_id: Badge::Editor).count.should eq(1)
    end

    it "grants and revokes trust level badges" do
      user.change_trust_level!(TrustLevel[4])
      BadgeGranter.process_queue!
      UserBadge.where(user_id: user.id, badge_id: Badge.trust_level_badge_ids).count.should eq(4)

      user.change_trust_level!(TrustLevel[1])
      BadgeGranter.backfill(Badge.find(1))
      BadgeGranter.backfill(Badge.find(2))
      UserBadge.where(user_id: user.id, badge_id: 1).first.should_not == nil
      UserBadge.where(user_id: user.id, badge_id: 2).first.should == nil
    end

    it "grants system like badges" do
      post = create_post(user: user)
      # Welcome badge
      action = PostAction.act(liker, post, PostActionType.types[:like])
      BadgeGranter.process_queue!
      UserBadge.find_by(user_id: user.id, badge_id: 5).should_not == nil

      post = create_post(topic: post.topic, user: user)
      action = PostAction.act(liker, post, PostActionType.types[:like])

      # Nice post badge
      post.update_attributes like_count: 10

      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!

      UserBadge.find_by(user_id: user.id, badge_id: Badge::NicePost).should_not == nil
      UserBadge.where(user_id: user.id, badge_id: Badge::NicePost).count.should == 1

      # Good post badge
      post.update_attributes like_count: 25
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!
      UserBadge.find_by(user_id: user.id, badge_id: Badge::GoodPost).should_not == nil

      # Great post badge
      post.update_attributes like_count: 50
      BadgeGranter.queue_badge_grant(Badge::Trigger::PostAction, post_action: action)
      BadgeGranter.process_queue!
      UserBadge.find_by(user_id: user.id, badge_id: Badge::GreatPost).should_not == nil

      # Revoke badges on unlike
      post.update_attributes like_count: 49
      BadgeGranter.backfill(Badge.find(Badge::GreatPost))
      UserBadge.find_by(user_id: user.id, badge_id: Badge::GreatPost).should == nil
    end
  end

end
