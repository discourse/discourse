require 'rails_helper'
require 'filter_best_posts'
require 'topic_view'

describe FilterBestPosts do

  let(:topic) { Fabricate(:topic) }
  let(:coding_horror) { Fabricate(:coding_horror) }
  let(:first_poster) { topic.user }

  let(:topic_view) { TopicView.new(topic.id, coding_horror) }

  let!(:p1) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 1) }
  let!(:p2) { Fabricate(:post, topic: topic, user: coding_horror, percent_rank: 0.5) }
  let!(:p3) { Fabricate(:post, topic: topic, user: first_poster, percent_rank: 0) }

  let(:moderator) { Fabricate(:moderator) }
  let(:admin) { Fabricate(:admin) }

  it "can find the best responses" do

    filtered_posts = TopicView.new(topic.id, coding_horror, best: 2).filtered_posts
    best2 = FilterBestPosts.new(topic, filtered_posts, 2)
    expect(best2.posts.count).to eq(2)
    expect(best2.posts[0].id).to eq(p2.id)
    expect(best2.posts[1].id).to eq(p3.id)

    topic.update_status('closed', true, Fabricate(:admin))
    expect(topic.posts.count).to eq(4)
  end

  describe "processing options" do
    before { @filtered_posts = TopicView.new(topic.id, nil, best: 99).filtered_posts }

    it "should not get the status post" do

      best = FilterBestPosts.new(topic, @filtered_posts, 99)
      expect(best.filtered_posts.size).to eq(3)
      expect(best.posts.map(&:id)).to match_array([p2.id, p3.id])

    end

    it "should get no results for trust level too low" do

      best = FilterBestPosts.new(topic, @filtered_posts, 99, min_trust_level: coding_horror.trust_level + 1)
      expect(best.posts.count).to eq(0)
    end

    it "should filter out the posts with a score that is too low" do

      best = FilterBestPosts.new(topic, @filtered_posts, 99, min_score: 99)
      expect(best.posts.count).to eq(0)
    end

    it "should filter out everything if min replies not met" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, min_replies: 99)
      expect(best.posts.count).to eq(0)
    end

    it "should punch through posts if the score is high enough" do
      p2.update_column(:score, 100)

      best = FilterBestPosts.new(topic, @filtered_posts, 99, bypass_trust_level_score: 100, min_trust_level: coding_horror.trust_level + 1)
      expect(best.posts.count).to eq(1)
    end

    it "should bypass trust level score" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, bypass_trust_level_score: 0, min_trust_level: coding_horror.trust_level + 1)
      expect(best.posts.count).to eq(0)
    end

    it "should return none if restricted to posts a moderator liked" do
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)
    end

    it "doesn't count likes from admins" do
      PostActionCreator.like(admin, p3)
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(0)
    end

    it "should find the post liked by the moderator" do
      PostActionCreator.like(moderator, p2)
      best = FilterBestPosts.new(topic, @filtered_posts, 99, only_moderator_liked: true)
      expect(best.posts.count).to eq(1)
    end

  end
end
