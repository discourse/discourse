# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCalculator do
  describe ".recalculate_for_sibling_group" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }

    it "uses its own engagement score instead of posts.score" do
      created_at = 1.day.ago
      stale_score_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      liked_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)

      stale_score_post.update_columns(
        created_at: created_at,
        score: 10_000,
        like_score: 0,
        reply_count: 0,
        incoming_link_count: 0,
        bookmark_count: 0,
        reads: 0,
      )
      liked_post.update_columns(
        created_at: created_at,
        score: nil,
        like_score: 1,
        reply_count: 0,
        incoming_link_count: 0,
        bookmark_count: 0,
        reads: 0,
      )

      described_class.recalculate_for_sibling_group(
        topic_id: topic.id,
        reply_to_post_number: op.post_number,
      )

      expect(NestedViewPostStat.find_by(post: liked_post).hot_score).to be >
        NestedViewPostStat.find_by(post: stale_score_post).hot_score
    end
  end
end
