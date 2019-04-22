# frozen_string_literal: true

require 'rails_helper'

describe SpamRule::FlagSockpuppets do

  fab!(:user1) { Fabricate(:user, ip_address: '182.189.119.174') }
  fab!(:post1) { Fabricate(:post, user: user1, topic: Fabricate(:topic, user: user1)) }

  describe 'perform' do
    let(:rule)        { described_class.new(post1) }
    subject(:perform) { rule.perform }

    it 'does nothing if flag_sockpuppets is disabled' do
      SiteSetting.flag_sockpuppets = false
      rule.expects(:reply_is_from_sockpuppet?).never
      rule.expects(:flag_sockpuppet_users).never
      expect(perform).to eq(false)
    end

    context 'flag_sockpuppets is enabled' do
      before { SiteSetting.flag_sockpuppets = true }

      it 'flags posts when it should' do
        rule.expects(:reply_is_from_sockpuppet?).returns(:true)
        rule.expects(:flag_sockpuppet_users).once
        expect(perform).to eq(true)
      end

      it "doesn't flag posts when it shouldn't" do
        rule.expects(:reply_is_from_sockpuppet?).returns(false)
        rule.expects(:flag_sockpuppet_users).never
        expect(perform).to eq(false)
      end
    end
  end

  describe 'reply_is_from_sockpuppet?' do
    it 'is false for the first post in a topic' do
      expect(described_class.new(post1).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is false if users have different IP addresses' do
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: '182.189.199.199'), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is true if users have the same IP address and are new' do
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: user1.ip_address), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(true)
    end

    it 'is false if the ip address is whitelisted' do
      ScreenedIpAddress.stubs(:is_whitelisted?).with(user1.ip_address).returns(true)
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: user1.ip_address), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is false if reply and first post are from the same user' do
      post2 = Fabricate(:post, user: user1, topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is false if first post user is staff' do
      staff1 = Fabricate(:admin, ip_address: '182.189.119.174')
      staff_post1 = Fabricate(:post, user: staff1, topic: Fabricate(:topic, user: staff1))
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: staff1.ip_address), topic: staff_post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is false if second post user is staff' do
      post2 = Fabricate(:post, user: Fabricate(:moderator, ip_address: user1.ip_address), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is false if both users are staff' do
      staff1 = Fabricate(:moderator, ip_address: '182.189.119.174')
      staff_post1 = Fabricate(:post, user: staff1, topic: Fabricate(:topic, user: staff1))
      post2 = Fabricate(:post, user: Fabricate(:admin, ip_address: staff1.ip_address), topic: staff_post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is true if first post user was created over 24 hours ago and has trust level higher than 0' do
      old_user = Fabricate(:user, ip_address: '182.189.119.174', created_at: 25.hours.ago, trust_level:  TrustLevel[1])
      first_post = Fabricate(:post, user: old_user, topic: Fabricate(:topic, user: old_user))
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: old_user.ip_address), topic: first_post.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(true)
    end

    it 'is false if second post user was created over 24 hours ago and has trust level higher than 0' do
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: user1.ip_address, created_at: 25.hours.ago, trust_level:  TrustLevel[1]), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end

    it 'is true if first post user was created less that 24 hours ago and has trust level higher than 0' do
      new_user = Fabricate(:user, ip_address: '182.189.119.174', created_at: 1.hour.ago, trust_level:  TrustLevel[1])
      first_post = Fabricate(:post, user: new_user, topic: Fabricate(:topic, user: new_user))
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: new_user.ip_address), topic: first_post.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(true)
    end

    it 'is true if second user was created less that 24 hours ago and has trust level higher than 0' do
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: user1.ip_address, created_at: 23.hours.ago, trust_level:  TrustLevel[1]), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(true)
    end

    # A weird case
    it 'is false when user is nil on first post' do
      post1.user = nil; post1.save!
      post2 = Fabricate(:post, user: Fabricate(:user), topic: post1.topic)
      expect(described_class.new(post2).reply_is_from_sockpuppet?).to eq(false)
    end
  end

  describe 'flag_sockpuppet_users' do
    fab!(:post2) { Fabricate(:post, user: Fabricate(:user, ip_address: user1.ip_address), topic: post1.topic) }
    let(:system) { Discourse.system_user }
    let(:spam) { PostActionType.types[:spam] }

    it 'flags post and first post if both users are new' do
      described_class.new(post2).flag_sockpuppet_users

      expect(PostAction.where(user: system, post: post1, post_action_type_id: spam).exists?).to eq(true)
      expect(PostAction.where(user: system, post: post2, post_action_type_id: spam).exists?).to eq(true)
    end

    it "doesn't flag the first post more than once" do
      described_class.new(post2).flag_sockpuppet_users

      expect(PostAction.where(user: system, post: post2, post_action_type_id: spam).exists?).to eq(true)
      expect(PostAction.where(post: post2, post_action_type_id: spam).count).to eq(1)
    end

    it "doesn't flag the first post if the user is not new" do
      old_user = Fabricate(:user, ip_address: '182.189.119.174', created_at: 25.hours.ago, trust_level:  TrustLevel[1])
      first_post = Fabricate(:post, user: old_user, topic: Fabricate(:topic, user: old_user))
      post2 = Fabricate(:post, user: Fabricate(:user, ip_address: old_user.ip_address), topic: first_post.topic)

      described_class.new(post2).flag_sockpuppet_users

      expect(PostAction.where(user: system, post: post2, post_action_type_id: spam).exists?).to eq(true)
      expect(PostAction.where(user: system, post: first_post, post_action_type_id: spam).exists?).to eq(false)
    end

    it "doesn't create a flag if user is nil on first post" do
      post1.user_id = nil
      post1.save
      described_class.new(post2).flag_sockpuppet_users

      expect(PostAction.where(user: system, post: post2, post_action_type_id: spam).exists?).to eq(true)
      expect(PostAction.where(user: system, post: post1, post_action_type_id: spam).exists?).to eq(false)
    end
  end
end
