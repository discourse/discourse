# frozen_string_literal: true

require 'rails_helper'

describe WatchedWord do
  fab!(:tl2_user) { Fabricate(:user, trust_level: TrustLevel[2]) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:moderator) { Fabricate(:moderator) }

  fab!(:topic) { Fabricate(:topic) }
  fab!(:first_post) { Fabricate(:post, topic: topic) }

  let(:require_approval_word) { Fabricate(:watched_word, action: WatchedWord.actions[:require_approval]) }
  let(:flag_word) { Fabricate(:watched_word, action: WatchedWord.actions[:flag]) }
  let(:block_word) { Fabricate(:watched_word, action: WatchedWord.actions[:block]) }
  let(:another_block_word) { Fabricate(:watched_word, action: WatchedWord.actions[:block]) }

  before_all do
    WordWatcher.clear_cache!
  end

  after do
    WordWatcher.clear_cache!
  end

  context "block" do
    def should_block_post(manager)
      expect {
        result = manager.perform
        expect(result).to_not be_success
        expect(result.errors[:base]&.first).to eq(I18n.t('contains_blocked_word', word: block_word.word))
      }.to_not change { Post.count }
    end

    it "should prevent the post from being created" do
      manager = NewPostManager.new(tl2_user, raw: "Want some #{block_word.word} for cheap?", topic_id: topic.id)
      should_block_post(manager)
    end

    it "look at title too" do
      manager = NewPostManager.new(tl2_user, title: "We sell #{block_word.word} online", raw: "Want some poutine for cheap?", topic_id: topic.id)
      should_block_post(manager)
    end

    it "should block the post from admin" do
      manager = NewPostManager.new(admin, raw: "Want some #{block_word.word} for cheap?", topic_id: topic.id)
      should_block_post(manager)
    end

    it "should block the post from moderator" do
      manager = NewPostManager.new(moderator, raw: "Want some #{block_word.word} for cheap?", topic_id: topic.id)
      should_block_post(manager)
    end

    it "should block the post if it contains multiple blocked words" do
      manager = NewPostManager.new(moderator, raw: "Want some #{block_word.word} #{another_block_word.word} for cheap?", topic_id: topic.id)
      expect {
        result = manager.perform
        expect(result).to_not be_success
        expect(result.errors[:base]&.first).to eq(I18n.t('contains_blocked_words', words: [block_word.word, another_block_word.word].sort.join(', ')))
      }.to_not change { Post.count }
    end

    it "should block in a private message too" do
      manager = NewPostManager.new(
        tl2_user,
        raw: "Want some #{block_word.word} for cheap?",
        title: 'this is a new title',
        archetype: Archetype.private_message,
        target_usernames: Fabricate(:user, trust_level: TrustLevel[2]).username
      )
      should_block_post(manager)
    end

    it "blocks on revisions" do
      post = Fabricate(:post, topic: Fabricate(:topic, user: tl2_user), user: tl2_user)
      expect {
        PostRevisor.new(post).revise!(post.user, { raw: "Want some #{block_word.word} for cheap?" }, revised_at: post.updated_at + 10.seconds)
        expect(post.errors).to be_present
        post.reload
      }.to_not change { post.raw }
    end
  end

  context "require_approval" do
    it "should queue the post for approval" do
      manager = NewPostManager.new(tl2_user, raw: "My dog's name is #{require_approval_word.word}.", topic_id: topic.id)
      result = manager.perform
      expect(result.action).to eq(:enqueued)
      expect(result.reason).to eq(:watched_word)
    end

    it "looks at title too" do
      manager = NewPostManager.new(tl2_user, title: "You won't believe these #{require_approval_word.word} dog names!", raw: "My dog's name is Porkins.", topic_id: topic.id)
      result = manager.perform
      expect(result.action).to eq(:enqueued)
    end

    it "should not queue posts from admin" do
      manager = NewPostManager.new(admin, raw: "My dog's name is #{require_approval_word.word}.", topic_id: topic.id)
      result = manager.perform
      expect(result).to be_success
      expect(result.action).to eq(:create_post)
    end

    it "should not queue posts from moderator" do
      manager = NewPostManager.new(moderator, raw: "My dog's name is #{require_approval_word.word}.", topic_id: topic.id)
      result = manager.perform
      expect(result).to be_success
      expect(result.action).to eq(:create_post)
    end

    it "doesn't need approval in a private message" do
      manager = NewPostManager.new(
        tl2_user,
        raw: "Want some #{require_approval_word.word} for cheap?",
        title: 'this is a new title',
        archetype: Archetype.private_message,
        target_usernames: Fabricate(:user, trust_level: TrustLevel[2]).username
      )
      result = manager.perform
      expect(result).to be_success
      expect(result.action).to eq(:create_post)
    end
  end

  context "flag" do
    def should_flag_post(author, raw, topic)
      post = Fabricate(:post, raw: raw, topic: topic, user: author)
      expect {
        Jobs::ProcessPost.new.execute(post_id: post.id)
      }.to change { PostAction.count }.by(1)
      expect(PostAction.where(post_id: post.id, post_action_type_id: PostActionType.types[:inappropriate]).exists?).to eq(true)
    end

    def should_not_flag_post(author, raw, topic)
      post = Fabricate(:post, raw: raw, topic: topic, user: author)
      expect {
        Jobs::ProcessPost.new.execute(post_id: post.id)
      }.to_not change { PostAction.count }
    end

    it "should flag the post as inappropriate" do
      should_flag_post(tl2_user, "I thought the #{flag_word.word} was bad.", Fabricate(:topic, user: tl2_user))
    end

    it "should look at the title too" do
      should_flag_post(tl2_user, "I thought the movie was not bad actually.", Fabricate(:topic, user: tl2_user, title: "Read my #{flag_word.word} review!"))
    end

    it "shouldn't flag posts by admin" do
      should_not_flag_post(admin, "I thought the #{flag_word.word} was bad.", Fabricate(:topic, user: admin))
    end

    it "shouldn't flag posts by moderator" do
      should_not_flag_post(moderator, "I thought the #{flag_word.word} was bad.", Fabricate(:topic, user: moderator))
    end

    it "is compatible with flag_sockpuppets" do
      SiteSetting.flag_sockpuppets = true
      ip_address = '182.189.119.174'
      user1 = Fabricate(:user, ip_address: ip_address, created_at: 2.days.ago)
      user2 = Fabricate(:user, ip_address: ip_address)
      first = create_post(user: user1, created_at: 2.days.ago)
      sockpuppet_post = create_post(user: user2, topic: first.topic, raw: "I thought the #{flag_word.word} was bad.")
      expect(PostAction.where(post_id: sockpuppet_post.id).count).to eq(1)
    end

    it "flags in private message too" do
      post = Fabricate(:private_message_post, raw: "Want some #{flag_word.word} for cheap?", user: tl2_user)
      expect {
        Jobs::ProcessPost.new.execute(post_id: post.id)
      }.to change { PostAction.count }.by(1)
      expect(PostAction.where(post_id: post.id, post_action_type_id: PostActionType.types[:inappropriate]).exists?).to eq(true)
    end

    it "flags on revisions" do
      Jobs.run_immediately!
      post = Fabricate(:post, topic: Fabricate(:topic, user: tl2_user), user: tl2_user)
      expect {
        PostRevisor.new(post).revise!(post.user, { raw: "Want some #{flag_word.word} for cheap?" }, revised_at: post.updated_at + 10.seconds)
      }.to change { PostAction.count }.by(1)
      expect(PostAction.where(post_id: post.id, post_action_type_id: PostActionType.types[:inappropriate]).exists?).to eq(true)
    end

    it "should not flag on rebake" do
      post = Fabricate(:post, topic: Fabricate(:topic, user: tl2_user), user: tl2_user, raw: "I have coupon codes. Message me.")
      Fabricate(:watched_word, action: WatchedWord.actions[:flag], word: "coupon")
      expect {
        post.rebake!
      }.to_not change { PostAction.count }
    end
  end
end
