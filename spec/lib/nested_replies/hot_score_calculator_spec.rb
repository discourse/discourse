# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCalculator do
  before { SiteSetting.nested_replies_enabled = true }

  def set_hot_score_inputs(post, created_at:, like_score: 0)
    post.update_columns(created_at: created_at, like_score: like_score)
  end

  describe ".score_for" do
    fab!(:topic)
    fab!(:post) { Fabricate(:post, topic: topic) }

    it "combines likes and direct replies logarithmically" do
      now = Time.zone.local(2026, 7, 10, 12)
      freeze_time(now)
      created_at = 2.days.ago
      set_hot_score_inputs(post, created_at: created_at, like_score: 3)

      score = described_class.score_for(post, direct_reply_count: 2)
      expected_engagement = 3 * described_class::LIKE_WEIGHT + 2 * described_class::REPLY_WEIGHT
      expected_freshness =
        described_class.freshness_max_bonus *
          0.5**(2.days.to_f / described_class.freshness_half_life_seconds)
      expected = Math.log(1 + expected_engagement) + expected_freshness

      expect(score).to be_within(0.0001).of(expected)
    end

    it "halves the freshness bonus each half-life", :aggregate_failures do
      now = Time.zone.local(2026, 7, 10, 12)
      freeze_time(now)
      set_hot_score_inputs(post, created_at: now)
      fresh_score = described_class.score_for(post)

      set_hot_score_inputs(post, created_at: now - described_class.freshness_half_life_seconds)
      one_half_life_score = described_class.score_for(post)

      expect(fresh_score).to be_within(0.0001).of(described_class.freshness_max_bonus)
      expect(one_half_life_score).to be_within(0.0001).of(described_class.freshness_max_bonus / 2)
    end

    it "lets engagement take over when a topic goes quiet", :aggregate_failures do
      now = Time.zone.local(2026, 7, 10, 12)
      freeze_time(now)
      newer_post = Fabricate(:post, topic: topic)
      set_hot_score_inputs(post, created_at: 7.days.ago, like_score: 3)
      set_hot_score_inputs(newer_post, created_at: now)

      expect(described_class.score_for(newer_post)).to be > described_class.score_for(post)

      much_later = now + 70.days

      expect(described_class.score_for(post, now: much_later)).to be >
        described_class.score_for(newer_post, now: much_later)
    end

    it "assigns no heat to posts hidden from the public", :aggregate_failures do
      created_at = Time.zone.local(2026, 7, 8, 12)
      whisper = Fabricate(:post, topic: topic, post_type: Post.types[:whisper])
      small_action = Fabricate(:small_action, topic: topic)
      hidden = Fabricate(:post, topic: topic, hidden: true)
      user_deleted = Fabricate(:post, topic: topic, user_deleted: true)
      deleted = Fabricate(:post, topic: topic, deleted_at: created_at)

      [whisper, small_action, hidden, user_deleted, deleted].each do |invisible_post|
        set_hot_score_inputs(invisible_post, created_at: created_at, like_score: 100)
      end

      expect(
        [whisper, small_action, hidden, user_deleted, deleted].map do |invisible_post|
          described_class.score_for(invisible_post)
        end,
      ).to all(eq(described_class::HOT_SCORE_FLOOR))
    end
  end

  describe ".recalculate_for_post" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

    it "subtracts a fixed penalty while bubbling heat", :aggregate_failures do
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(parent, created_at: 1.day.ago)
      set_hot_score_inputs(child, created_at: 12.hours.ago, like_score: 10)

      described_class.recalculate_for_post(child.id)

      parent_stat = NestedViewPostStat.find_by!(post: parent)
      child_stat = NestedViewPostStat.find_by!(post: child)
      expect(parent_stat.thread_hot_score).to be_within(0.0001).of(
        child_stat.thread_hot_score - described_class.child_penalty,
      )
      expect(parent_stat.thread_hot_score).to be > parent_stat.hot_score
    end

    it "applies the penalty once per ancestor edge", :aggregate_failures do
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      parent = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      grandchild = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(root, created_at: 2.days.ago)
      set_hot_score_inputs(parent, created_at: 1.day.ago)
      set_hot_score_inputs(grandchild, created_at: 12.hours.ago, like_score: 20)

      described_class.recalculate_for_post(grandchild.id)

      root_stat = NestedViewPostStat.find_by!(post: root)
      parent_stat = NestedViewPostStat.find_by!(post: parent)
      grandchild_stat = NestedViewPostStat.find_by!(post: grandchild)
      expect(parent_stat.thread_hot_score).to be_within(0.0001).of(
        grandchild_stat.thread_hot_score - described_class.child_penalty,
      )
      expect(root_stat.thread_hot_score).to be_within(0.0001).of(
        grandchild_stat.thread_hot_score - 2 * described_class.child_penalty,
      )
    end

    it "falls back to the next hottest child after a decrease", :aggregate_failures do
      root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      hottest_child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      next_child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
      set_hot_score_inputs(root, created_at: 2.days.ago)
      set_hot_score_inputs(hottest_child, created_at: 1.day.ago, like_score: 100)
      set_hot_score_inputs(next_child, created_at: 1.day.ago, like_score: 10)
      described_class.recalculate_topic(topic.id)
      original_thread_score = NestedViewPostStat.find_by!(post: root).thread_hot_score

      hottest_child.update_columns(like_score: 0)
      described_class.recalculate_for_post(hottest_child.id)

      root_stat = NestedViewPostStat.find_by!(post: root)
      next_child_stat = NestedViewPostStat.find_by!(post: next_child)
      expect(root_stat.thread_hot_score).to be < original_thread_score
      expect(root_stat.thread_hot_score).to be_within(0.0001).of(
        next_child_stat.thread_hot_score - described_class.child_penalty,
      )
    end

    it "moves branch heat from an old parent to a new parent", :aggregate_failures do
      old_parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      new_parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: old_parent.post_number)
      set_hot_score_inputs(old_parent, created_at: 2.days.ago)
      set_hot_score_inputs(new_parent, created_at: 2.days.ago)
      set_hot_score_inputs(child, created_at: 1.day.ago, like_score: 100)
      described_class.recalculate_topic(topic.id)
      old_parent_score = NestedViewPostStat.find_by!(post: old_parent).thread_hot_score
      new_parent_score = NestedViewPostStat.find_by!(post: new_parent).thread_hot_score

      previous_parent_number = child.reply_to_post_number
      child.update_columns(reply_to_post_number: new_parent.post_number)
      described_class.recalculate_after_reparent(child, previous_parent_number)

      expect(NestedViewPostStat.find_by!(post: old_parent).thread_hot_score).to be <
        old_parent_score
      expect(NestedViewPostStat.find_by!(post: new_parent).thread_hot_score).to be >
        new_parent_score
    end

    it "serializes path updates by topic" do
      child = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      allow(DistributedMutex).to receive(:synchronize).and_yield

      described_class.recalculate_for_post(child.id)

      expect(DistributedMutex).to have_received(:synchronize).with(
        "nested_hot_scores_topic_#{topic.id}",
        validity: described_class::LOCK_VALIDITY_SECONDS,
      )
    end

    it "lowers and restores branch heat when a post is hidden and unhidden" do
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(parent, created_at: 3.days.ago)
      set_hot_score_inputs(child, created_at: 1.day.ago, like_score: 100)
      described_class.recalculate_topic(topic.id)
      hot_branch_score = NestedViewPostStat.find_by!(post: parent).thread_hot_score

      child.update!(hidden: true)
      hidden_branch_score = NestedViewPostStat.find_by!(post: parent).thread_hot_score
      child.update!(hidden: false)

      expect(hidden_branch_score).to be < hot_branch_score
      expect(NestedViewPostStat.find_by!(post: parent).thread_hot_score).to be_within(0.0001).of(
        hot_branch_score,
      )
    end

    it "removes and restores branch heat when a post changes public type" do
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(parent, created_at: 3.days.ago)
      set_hot_score_inputs(child, created_at: 1.day.ago, like_score: 100)
      described_class.recalculate_topic(topic.id)
      hot_branch_score = NestedViewPostStat.find_by!(post: parent).thread_hot_score

      child.update!(post_type: Post.types[:whisper])
      whisper_branch_score = NestedViewPostStat.find_by!(post: parent).thread_hot_score
      child.update!(post_type: Post.types[:regular])

      expect(whisper_branch_score).to be < hot_branch_score
      expect(NestedViewPostStat.find_by!(post: parent).thread_hot_score).to be_within(0.0001).of(
        hot_branch_score,
      )
    end
  end

  describe ".recalculate_topic" do
    fab!(:topic)
    fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
    fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

    it "counts only public visible direct replies" do
      created_at = Time.zone.local(2026, 7, 8, 12)
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      visible_reply = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
      whisper =
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: parent.post_number,
          post_type: Post.types[:whisper],
        )
      small_action =
        Fabricate(:small_action, topic: topic, reply_to_post_number: parent.post_number)
      hidden_reply =
        Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number, hidden: true)
      user_deleted_reply =
        Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number, user_deleted: true)
      deleted_reply =
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: parent.post_number,
          deleted_at: created_at,
        )

      [
        parent,
        visible_reply,
        whisper,
        small_action,
        hidden_reply,
        user_deleted_reply,
        deleted_reply,
      ].each { |post| set_hot_score_inputs(post, created_at: created_at) }

      described_class.recalculate_topic(topic.id)

      parent_stat = NestedViewPostStat.find_by!(post: parent)
      expect(parent_stat.hot_score).to be_within(0.0001).of(
        described_class.score_for(parent, direct_reply_count: 1),
      )
    end

    it "ignores likes on whispers and small actions", :aggregate_failures do
      parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
      whisper =
        Fabricate(
          :post,
          topic: topic,
          reply_to_post_number: parent.post_number,
          post_type: Post.types[:whisper],
        )
      small_action =
        Fabricate(:small_action, topic: topic, reply_to_post_number: parent.post_number)
      set_hot_score_inputs(parent, created_at: 1.day.ago)
      set_hot_score_inputs(whisper, created_at: 1.hour.ago, like_score: 100)
      set_hot_score_inputs(small_action, created_at: 1.hour.ago, like_score: 100)

      described_class.recalculate_topic(topic.id)

      parent_stat = NestedViewPostStat.find_by!(post: parent)
      expect(NestedViewPostStat.find_by!(post: whisper).hot_score).to eq(0.0)
      expect(NestedViewPostStat.find_by!(post: small_action).hot_score).to eq(0.0)
      expect(parent_stat.thread_hot_score).to eq(parent_stat.hot_score)
    end
  end

  describe ".recalculate_for_post_if_nested" do
    fab!(:author) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:liker) { Fabricate(:user, refresh_auto_groups: true) }
    fab!(:admin)
    fab!(:topic) { Fabricate(:topic, user: author) }
    fab!(:op) { Fabricate(:post, topic: topic, user: author, post_number: 1) }
    fab!(:post) do
      Fabricate(:post, topic: topic, user: author, reply_to_post_number: op.post_number)
    end

    it "creates a missing score row for a nested topic" do
      Fabricate(:nested_topic, topic: topic)
      NestedViewPostStat.where(post_id: post.id).delete_all

      expect { described_class.recalculate_for_post_if_nested(post.id) }.to change {
        NestedViewPostStat.exists?(post_id: post.id)
      }.from(false).to(true)
    end

    it "does not create a score row for a flat topic" do
      NestedViewPostStat.where(post_id: post.id).delete_all

      described_class.recalculate_for_post_if_nested(post.id)

      expect(NestedViewPostStat.find_by(post: post)).to be_nil
    end

    it "raises and lowers branch scores with a like", :aggregate_failures do
      Fabricate(:nested_topic, topic: topic)
      child = Fabricate(:post, topic: topic, user: author, reply_to_post_number: post.post_number)
      set_hot_score_inputs(post, created_at: 30.days.ago)
      set_hot_score_inputs(child, created_at: 1.hour.ago)
      described_class.recalculate_topic(topic.id)
      original_child_score = NestedViewPostStat.find_by!(post: child).hot_score
      original_parent_score = NestedViewPostStat.find_by!(post: post).thread_hot_score

      expect(PostActionCreator.like(liker, child)).to be_success

      liked_child_score = NestedViewPostStat.find_by!(post: child).hot_score
      liked_parent_score = NestedViewPostStat.find_by!(post: post).thread_hot_score
      expect(liked_child_score).to be > original_child_score
      expect(liked_parent_score).to be > original_parent_score

      expect(PostActionDestroyer.destroy(liker, child, :like)).to be_success

      expect(NestedViewPostStat.find_by!(post: child).hot_score).to be_within(0.0001).of(
        original_child_score,
      )
      expect(NestedViewPostStat.find_by!(post: post).thread_hot_score).to be_within(0.0001).of(
        original_parent_score,
      )
    end

    it "scores a reply after PostCreator saves its relationship", :aggregate_failures do
      Fabricate(:nested_topic, topic: topic)
      set_hot_score_inputs(post, created_at: 1.day.ago)
      described_class.recalculate_topic(topic.id)
      original_score = NestedViewPostStat.find_by!(post: post).hot_score

      reply =
        PostCreator.create!(
          liker,
          topic_id: topic.id,
          reply_to_post_number: post.post_number,
          raw: "A direct reply with enough detail for this test.",
        )

      post.reload
      parent_stat = NestedViewPostStat.find_by!(post: post)
      expect(post.reply_count).to eq(1)
      expect(parent_stat.hot_score).to be_within(0.0001).of(
        described_class.score_for(post, direct_reply_count: 1),
      )
      expect(parent_stat.hot_score).to be > original_score

      PostDestroyer.new(admin, reply).destroy

      expect(NestedViewPostStat.find_by!(post: post).hot_score).to be_within(0.0001).of(
        original_score,
      )
    end
  end
end
