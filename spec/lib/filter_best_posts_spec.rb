# frozen_string_literal: true

require "filter_best_posts"
require "topic_view"

RSpec.describe FilterBestPosts do
  fab!(:topic)
  fab!(:coding_horror)
  fab!(:first_poster) { topic.user }

  fab!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1) }
  fab!(:p2) { Fabricate(:post, topic: topic, user: coding_horror, percent_rank: 0.5) }
  fab!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0) }

  fab!(:moderator)
  fab!(:admin)

  it "can find the best responses" do
    filtered_posts = TopicView.new(topic.id, coding_horror, best: 2).filtered_posts
    best2 = FilterBestPosts.new(topic, filtered_posts, 2)
    expect(best2.posts.count).to eq(2)
    expect(best2.posts[0].id).to eq(p2.id)
    expect(best2.posts[1].id).to eq(p3.id)

    topic.update_status("closed", true, Fabricate(:admin))
    expect(topic.posts.count).to eq(4)
  end

  describe "processing options" do
    before { @filtered_posts = TopicView.new(topic.id, nil, best: 99).filtered_posts }

    it "excludes the status post" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99)
      expect(best.filtered_posts.size).to eq(3)
      expect(best.posts.map(&:id)).to match_array([p2.id, p3.id])
    end

    it "returns no results below the minimum trust level" do
      best =
        FilterBestPosts.new(
          topic,
          @filtered_posts,
          99,
          min_trust_level: coding_horror.trust_level + 1,
        )
      expect(best.posts.count).to eq(0)
    end

    it "excludes posts below the minimum score" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, min_score: 99)
      expect(best.posts.count).to eq(0)
    end

    it "returns no posts below the minimum reply count" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, min_replies: 99)
      expect(best.posts.count).to eq(0)
    end

    it "includes posts whose score exceeds the threshold" do
      p2.update_column(:score, 100)

      best =
        FilterBestPosts.new(
          topic,
          @filtered_posts,
          99,
          bypass_trust_level_score: 100,
          min_trust_level: coding_horror.trust_level + 1,
        )
      expect(best.posts.count).to eq(1)
    end

    it "bypasses the trust-level score" do
      best =
        FilterBestPosts.new(
          topic,
          @filtered_posts,
          99,
          bypass_trust_level_score: 0,
          min_trust_level: coding_horror.trust_level + 1,
        )
      expect(best.posts.count).to eq(0)
    end

    it "returns none when no posts were liked by a moderator" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)
    end

    it "doesn't count likes from admins" do
      PostActionCreator.like(admin, p3)
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)
    end

    it "returns a post liked by a moderator" do
      PostActionCreator.like(moderator, p2)
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(1)
    end
  end
end
