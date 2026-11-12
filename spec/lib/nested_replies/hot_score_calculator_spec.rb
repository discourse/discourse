# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCalculator do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }

  def set_score_inputs(post, created_at:, like_score: 0)
    post.update_columns(created_at: created_at, like_score: like_score)
  end

  def cached_score(post)
    DB.query(<<~SQL, post_id: post.id).first
      SELECT hot_score,
             thread_hot_score
      FROM nested_hot_post_scores
      WHERE post_id = :post_id
    SQL
  end

  describe ".score_for" do
    it "combines engagement and freshness while excluding non-public posts" do
      SiteSetting.nested_replies_hot_like_weight = 1.5
      SiteSetting.nested_replies_hot_reply_weight = 2.5
      SiteSetting.nested_replies_hot_freshness_max_bonus = 4.0
      SiteSetting.nested_replies_hot_freshness_half_life_hours = 48
      now = Time.zone.local(2026, 7, 10, 12)
      public_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      hidden_post = Fabricate(:post, topic: topic, hidden: true)
      set_score_inputs(public_post, created_at: now - 2.days, like_score: 3)
      set_score_inputs(hidden_post, created_at: now, like_score: 100)

      engagement =
        3 * SiteSetting.nested_replies_hot_like_weight +
          2 * SiteSetting.nested_replies_hot_reply_weight
      freshness =
        SiteSetting.nested_replies_hot_freshness_max_bonus *
          0.5**(2.days.to_f / SiteSetting.nested_replies_hot_freshness_half_life_hours.hours.to_f)

      expect(described_class.score_for(public_post, direct_reply_count: 2, now: now)).to be_within(
        0.0001,
      ).of(Math.log(1 + engagement) + freshness)
      expect(described_class.score_for(hidden_post, now: now)).to eq(
        described_class::HOT_SCORE_FLOOR,
      )
    end
  end

  describe ".recalculate_topic" do
    it "publishes an isolated coherent snapshot using only public direct replies" do
      SiteSetting.nested_replies_hot_like_weight = 1.5
      SiteSetting.nested_replies_hot_reply_weight = 2.5
      SiteSetting.nested_replies_hot_freshness_max_bonus = 4.0
      SiteSetting.nested_replies_hot_freshness_half_life_hours = 48
      SiteSetting.nested_replies_hot_child_penalty = 0.5
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      public_child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      Fabricate(
        :post,
        topic: topic,
        reply_to_post_number: parent.post_number,
        post_type: Post.types[:whisper],
      )
      set_score_inputs(parent, created_at: 2.days.ago)
      set_score_inputs(public_child, created_at: 1.day.ago, like_score: 20)
      structural_stat = NestedViewPostStat.create!(post: parent, total_descendant_count: 42)

      expect(described_class.recalculate_topic(topic.id)).to eq(2)

      parent_score = cached_score(parent)
      child_score = cached_score(public_child)
      snapshot =
        DB.query(
          "SELECT calculated_at FROM nested_hot_score_snapshots WHERE topic_id = :topic_id",
          topic_id: topic.id,
        ).first
      expect(parent_score.hot_score).to be_within(0.0001).of(
        described_class.score_for(parent, direct_reply_count: 1),
      )
      expect(parent_score.thread_hot_score).to be_within(0.0001).of(
        child_score.thread_hot_score - SiteSetting.nested_replies_hot_child_penalty,
      )
      expect(snapshot.calculated_at).to be_present
      expect(structural_stat.reload.total_descendant_count).to eq(42)
      expect(NestedViewPostStat.where(post: [op, public_child]).count).to eq(0)
    end

    it "propagates public descendant heat through a deleted placeholder" do
      SiteSetting.nested_replies_hot_child_penalty = 0.5
      deleted_root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child =
        Fabricate(:post, topic: topic, reply_to_post_number: deleted_root.post_number).tap do |post|
          set_score_inputs(post, created_at: 1.hour.ago, like_score: 100)
        end
      deleted_root.update_columns(deleted_at: Time.current, like_score: 100)

      described_class.recalculate_topic(topic.id)

      deleted_root_score = cached_score(deleted_root)
      child_score = cached_score(child)
      expect(deleted_root_score.hot_score).to eq(described_class::HOT_SCORE_FLOOR)
      expect(deleted_root_score.thread_hot_score).to be_within(0.0001).of(
        child_score.thread_hot_score - SiteSetting.nested_replies_hot_child_penalty,
      )
    end

    it "rejects a cycle without publishing partial cache rows" do
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      root.update_columns(reply_to_post_number: child.post_number)

      expect { described_class.recalculate_topic(topic.id) }.to raise_error(
        described_class::InvalidTree,
      )
      expect(
        DB.query_single(
          "SELECT 1 FROM nested_hot_post_scores WHERE topic_id = :topic_id",
          topic_id: topic.id,
        ),
      ).to be_empty
      expect(
        DB.query_single(
          "SELECT 1 FROM nested_hot_score_snapshots WHERE topic_id = :topic_id",
          topic_id: topic.id,
        ),
      ).to be_empty
    end

    it "rejects a topic without an original post" do
      op.update_columns(post_number: 99)

      expect { described_class.recalculate_topic(topic.id) }.to raise_error(
        described_class::MissingOriginalPost,
      )
      expect(
        DB.query_single(
          "SELECT 1 FROM nested_hot_score_snapshots WHERE topic_id = :topic_id",
          topic_id: topic.id,
        ),
      ).to be_empty
    end
  end
end
