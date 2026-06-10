# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCalculator do
  before { SiteSetting.nested_replies_enabled = true }

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

  describe ".recalculate_parents_for_post_numbers" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:parent) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }

    it "recalculates parent posts when their reply engagement changes" do
      described_class.recalculate_for_post(parent.id)
      original_score = NestedViewPostStat.find_by!(post: parent).hot_score

      parent.update_columns(reply_count: parent.reply_count + 5)
      described_class.recalculate_parents_for_post_numbers(
        topic_id: topic.id,
        post_numbers: [parent.post_number],
      )

      expect(NestedViewPostStat.find_by!(post: parent).hot_score).to be > original_score
    end
  end

  describe ".recalculate_for_post_if_nested" do
    fab!(:user)
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:post) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }

    it "updates hot score for posts in nested topics" do
      Fabricate(:nested_topic, topic: topic)

      described_class.recalculate_for_post_if_nested(post.id)

      expect(NestedViewPostStat.find_by(post: post).hot_score_updated_at).to be_present
    end

    it "does not create hot score rows for non-nested topics" do
      NestedViewPostStat.where(post_id: post.id).delete_all

      described_class.recalculate_for_post_if_nested(post.id)

      expect(NestedViewPostStat.find_by(post: post)).to be_nil
    end

    it "updates hot score after a post bookmark changes" do
      Fabricate(:nested_topic, topic: topic)
      described_class.recalculate_for_post(post.id)
      original_score = NestedViewPostStat.find_by!(post: post).hot_score

      BookmarkManager.new(user).create_for(bookmarkable_id: post.id, bookmarkable_type: "Post")

      expect(post.reload.bookmark_count).to eq(1)
      expect(NestedViewPostStat.find_by!(post: post).hot_score).to be > original_score
    end
  end
end
