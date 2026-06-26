# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCalculator do
  before { SiteSetting.nested_replies_enabled = true }

  def set_hot_score_inputs(post, created_at:, like_score: 0)
    post.update_columns(
      created_at: created_at,
      like_score: like_score,
      reply_count: 0,
      incoming_link_count: 0,
      bookmark_count: 0,
      reads: 0,
    )
  end

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

    it "bubbles a hot child into its parent's thread score", :aggregate_failures do
      SiteSetting.nested_replies_hot_score_child_decay = 0.5
      old_created_at = Time.zone.at(0)
      recent_created_at = Time.zone.local(2026, 6, 1)
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(parent, created_at: old_created_at)
      set_hot_score_inputs(child, created_at: recent_created_at, like_score: 100)

      described_class.recalculate_for_post(parent.id)
      parent_own_score = NestedViewPostStat.find_by!(post: parent).hot_score
      described_class.recalculate_for_sibling_group(
        topic_id: topic.id,
        reply_to_post_number: parent.post_number,
      )

      parent_stat = NestedViewPostStat.find_by!(post: parent)
      child_stat = NestedViewPostStat.find_by!(post: child)
      expect(parent_stat.hot_score).to eq(parent_own_score)
      expect(parent_stat.thread_hot_score).to be_within(0.0001).of(
        child_stat.thread_hot_score * described_class.hot_score_child_decay,
      )
      expect(parent_stat.thread_hot_score).to be > parent_stat.hot_score
    end

    it "bubbles a hot grandchild through parent and root", :aggregate_failures do
      old_created_at = Time.zone.at(0)
      recent_created_at = Time.zone.local(2026, 6, 1)
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      parent = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      grandchild = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(root, created_at: old_created_at)
      set_hot_score_inputs(parent, created_at: old_created_at)
      set_hot_score_inputs(grandchild, created_at: recent_created_at, like_score: 100)

      described_class.recalculate_for_post(root.id)
      described_class.recalculate_for_post(parent.id)
      described_class.recalculate_for_sibling_group(
        topic_id: topic.id,
        reply_to_post_number: parent.post_number,
      )

      root_stat = NestedViewPostStat.find_by!(post: root)
      parent_stat = NestedViewPostStat.find_by!(post: parent)
      grandchild_stat = NestedViewPostStat.find_by!(post: grandchild)
      expect(parent_stat.thread_hot_score).to be_within(0.0001).of(
        grandchild_stat.thread_hot_score * described_class.hot_score_child_decay,
      )
      expect(root_stat.thread_hot_score).to be_within(0.0001).of(
        parent_stat.thread_hot_score * described_class.hot_score_child_decay,
      )
      expect(root_stat.thread_hot_score).to be > root_stat.hot_score
    end

    it "stores relative scores from the sibling distribution", :aggregate_failures do
      created_at = 1.day.ago
      cold_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      hot_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      set_hot_score_inputs(cold_post, created_at: created_at)
      set_hot_score_inputs(hot_post, created_at: created_at, like_score: 100)

      described_class.recalculate_for_sibling_group(
        topic_id: topic.id,
        reply_to_post_number: op.post_number,
      )

      cold_stat = NestedViewPostStat.find_by!(post: cold_post)
      hot_stat = NestedViewPostStat.find_by!(post: hot_post)
      expect(hot_stat.relative_hot_score).to be > described_class::RELATIVE_HOT_SCORE_BASELINE
      expect(cold_stat.relative_hot_score).to be < described_class::RELATIVE_HOT_SCORE_BASELINE
      expect(hot_stat.relative_hot_score).to be > cold_stat.relative_hot_score
    end

    it "groups topic-level and OP replies for relative scores", :aggregate_failures do
      cold_created_at = Time.zone.local(2026, 5, 1)
      hot_created_at = Time.zone.local(2026, 6, 1)
      cold_posts =
        11.times.map do
          Fabricate(:post, topic: topic, reply_to_post_number: nil).tap do |post|
            set_hot_score_inputs(post, created_at: cold_created_at)
          end
        end
      hot_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      set_hot_score_inputs(hot_post, created_at: hot_created_at, like_score: 100)

      described_class.recalculate_for_sibling_group(topic_id: topic.id, reply_to_post_number: nil)

      cold_stat = NestedViewPostStat.find_by!(post: cold_posts.first)
      hot_stat = NestedViewPostStat.find_by!(post: hot_post)
      expect(hot_stat.relative_hot_score).to be > described_class::RELATIVE_HOT_SCORE_BASELINE
      expect(hot_stat.relative_hot_score).to be > cold_stat.relative_hot_score
    end

    it "bubbles relative heat through ancestors", :aggregate_failures do
      old_created_at = Time.zone.at(0)
      recent_created_at = Time.zone.local(2026, 6, 1)
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      parent = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      hot_grandchild = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      cold_grandchild = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(root, created_at: old_created_at)
      set_hot_score_inputs(parent, created_at: old_created_at)
      set_hot_score_inputs(hot_grandchild, created_at: recent_created_at, like_score: 100)
      set_hot_score_inputs(cold_grandchild, created_at: old_created_at)

      described_class.recalculate_for_post(root.id)
      described_class.recalculate_for_post(parent.id)
      described_class.recalculate_for_sibling_group(
        topic_id: topic.id,
        reply_to_post_number: parent.post_number,
      )

      root_stat = NestedViewPostStat.find_by!(post: root)
      parent_stat = NestedViewPostStat.find_by!(post: parent)
      hot_grandchild_stat = NestedViewPostStat.find_by!(post: hot_grandchild)
      expect(parent_stat.relative_thread_hot_score).to be_within(0.0001).of(
        hot_grandchild_stat.relative_thread_hot_score * described_class.hot_score_child_decay,
      )
      expect(root_stat.relative_thread_hot_score).to be_within(0.0001).of(
        parent_stat.relative_thread_hot_score * described_class.hot_score_child_decay,
      )
      expect(root_stat.relative_thread_hot_score).to be > root_stat.relative_hot_score
    end
  end

  describe ".recalculate_for_post" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }

    it "updates ancestor thread scores when own score changes" do
      old_created_at = Time.zone.at(0)
      recent_created_at = Time.zone.local(2026, 6, 1)
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      set_hot_score_inputs(root, created_at: old_created_at)
      set_hot_score_inputs(child, created_at: old_created_at)
      described_class.recalculate_for_post(root.id)
      described_class.recalculate_for_post(child.id)
      original_thread_score = NestedViewPostStat.find_by!(post: root).thread_hot_score

      set_hot_score_inputs(child, created_at: recent_created_at, like_score: 100)
      described_class.recalculate_for_post(child.id)

      expect(NestedViewPostStat.find_by!(post: root).thread_hot_score).to be > original_thread_score
    end

    it "updates sibling relative scores when one score changes", :aggregate_failures do
      created_at = 1.day.ago
      first = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      second = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      set_hot_score_inputs(first, created_at: created_at)
      set_hot_score_inputs(second, created_at: created_at)
      described_class.recalculate_for_post(first.id)

      set_hot_score_inputs(second, created_at: created_at, like_score: 100)
      described_class.recalculate_for_post(second.id)

      first_stat = NestedViewPostStat.find_by!(post: first)
      second_stat = NestedViewPostStat.find_by!(post: second)
      expect(first_stat.relative_hot_score).to be < described_class::RELATIVE_HOT_SCORE_BASELINE
      expect(second_stat.relative_hot_score).to be > described_class::RELATIVE_HOT_SCORE_BASELINE
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
