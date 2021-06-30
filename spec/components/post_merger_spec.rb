# frozen_string_literal: true

require 'rails_helper'
require 'post_merger'

describe PostMerger do
  fab!(:moderator) { Fabricate(:moderator) }
  fab!(:admin) { Fabricate(:admin) }
  fab!(:user) { Fabricate(:user) }
  let(:post) { create_post }
  let(:topic) { post.topic }

  describe ".merge" do
    it "should merge posts into the latest post correctly" do
      reply1 = create_post(topic: topic, raw: 'The first reply', post_number: 2, user: user)
      reply2 = create_post(topic: topic, raw: "The second reply\nSecond line", post_number: 3, user: user)
      reply3 = create_post(topic: topic, raw: 'The third reply', post_number: 4, user: user)
      replies = [reply3, reply2, reply1]

      message = MessageBus.track_publish("/topic/#{topic.id}") { PostMerger.new(admin, replies).merge }.last

      expect(message.data[:type]).to eq(:revised)
      expect(message.data[:post_number]).to eq(reply3.post_number)

      expect(reply1.trashed?).to eq(true)
      expect(reply2.trashed?).to eq(true)
      expect(reply3.deleted_at).to eq(nil)

      expect(reply3.edit_reason).to eq(I18n.t(
        "merge_posts.edit_reason",
        count: replies.count - 1, username: admin.username
      ))

      expect(reply3.raw).to eq(
        "The first reply\n\nThe second reply\nSecond line\n\nThe third reply"
      )
    end

    it "should not allow the first post in a topic to be merged" do
      post.update!(user: user)
      reply1 = create_post(topic: topic, post_number: post.post_number, user: user)
      reply2 = create_post(topic: topic, post_number: post.post_number, user: user)

      expect { PostMerger.new(admin, [reply2, post, reply1]).merge }.to raise_error(Discourse::InvalidAccess)
    end

    it "should only allow staff to merge posts" do
      reply1 = create_post(topic: topic, post_number: post.post_number, user: user)
      reply2 = create_post(topic: topic, post_number: post.post_number, user: user)

      merged_raw = reply1.raw + "\n\n" + reply2.raw

      tl1 = Fabricate(:user, trust_level: 1)
      tl2 = Fabricate(:user, trust_level: 2)
      tl3 = Fabricate(:user, trust_level: 3)
      tl4 = Fabricate(:user, trust_level: 4)

      expect { PostMerger.new(tl1, [reply2, reply1]).merge }.to raise_error(Discourse::InvalidAccess)
      expect { PostMerger.new(tl2, [reply2, reply1]).merge }.to raise_error(Discourse::InvalidAccess)
      expect { PostMerger.new(tl3, [reply2, reply1]).merge }.to raise_error(Discourse::InvalidAccess)
      expect { PostMerger.new(tl4, [reply2, reply1]).merge }.to raise_error(Discourse::InvalidAccess)

      PostMerger.new(Fabricate(:admin), [reply2, reply1]).merge

      expect(reply1.trashed?).to eq(true)
      expect(reply2.trashed?).to eq(false)

      expect(reply2.raw).to eq(merged_raw)
    end

    it "should not allow posts from different topics to be merged" do
      another_post = create_post(user: post.user)

      expect { PostMerger.new(user, [another_post, post]).merge }.to raise_error(
        PostMerger::CannotMergeError, I18n.t("merge_posts.errors.different_topics")
      )
    end

    it "should not allow posts from different users to be merged" do
      another_post = create_post(user: user, topic_id: topic.id)

      expect { PostMerger.new(user, [another_post, post]).merge }.to raise_error(
        PostMerger::CannotMergeError, I18n.t("merge_posts.errors.different_users")
      )
    end

    it "should not allow posts with length greater than max_post_length" do
      SiteSetting.max_post_length = 60

      reply1 = create_post(topic: topic, raw: 'The first reply', post_number: 2, user: user)
      reply2 = create_post(topic: topic, raw: "The second reply\nSecond line", post_number: 3, user: user)
      reply3 = create_post(topic: topic, raw: 'The third reply', post_number: 4, user: user)
      replies = [reply3, reply2, reply1]

      expect { PostMerger.new(admin, replies).merge }.to raise_error(
        PostMerger::CannotMergeError, I18n.t("merge_posts.errors.max_post_length")
      )
    end
  end
end
