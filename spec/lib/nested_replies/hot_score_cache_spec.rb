# frozen_string_literal: true

RSpec.describe NestedReplies::HotScoreCache do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_hot_sort_enabled = true
    Fabricate(:nested_topic, topic: topic)
    topic.update_columns(posts_count: 6)
    NestedReplies::HotScoreQueue.clear
  end

  after { NestedReplies::HotScoreQueue.clear }

  def create_topic_with_snapshot(
    calculated_at:,
    formula_version: NestedReplies::HotScoreCalculator::FORMULA_VERSION
  )
    cached_topic = Fabricate(:topic)
    cached_post = Fabricate(:post, topic: cached_topic, post_number: 1)
    Fabricate(:nested_topic, topic: cached_topic)
    cached_topic.update_columns(posts_count: 6)
    DB.exec(
      <<~SQL,
      INSERT INTO nested_hot_score_snapshots (topic_id, formula_version, calculated_at)
      VALUES (:topic_id, :formula_version, :calculated_at)
    SQL
      topic_id: cached_topic.id,
      formula_version: formula_version,
      calculated_at: calculated_at,
    )
    [cached_topic, cached_post]
  end

  it "does no cache work for disabled, non-hot, ineligible, or small-topic requests" do
    non_hot = described_class.resolve(topic, "new")
    SiteSetting.nested_replies_hot_sort_enabled = false
    disabled = described_class.resolve(topic, "hot")
    SiteSetting.nested_replies_hot_sort_enabled = true
    ineligible = described_class.resolve(Fabricate(:topic, posts_count: 6), "hot")
    topic.update_columns(posts_count: described_class::SMALL_TOPIC_POST_LIMIT)
    small_topic = described_class.resolve(topic, "hot")

    expect([non_hot.effective_sort, non_hot.mode]).to eq(["new", :not_hot])
    expect([disabled.effective_sort, disabled.mode]).to eq(["top", :disabled])
    expect([ineligible.effective_sort, ineligible.mode]).to eq(["top", :ineligible])
    expect([small_topic.effective_sort, small_topic.mode]).to eq(["top", :small_topic])
    expect(NestedReplies::HotScoreQueue.size).to eq(0)
  end

  it "deduplicates demand for a missing topic without imposing a size ceiling" do
    topic.update_columns(posts_count: 1_000_000)

    first_decision = described_class.resolve(topic, "hot")
    second_decision = described_class.resolve(topic, "hot")

    expect(
      [first_decision.effective_sort, first_decision.mode, first_decision.enqueue_result],
    ).to eq(["top", :missing, :queued])
    expect(second_decision.enqueue_result).to eq(:duplicate)
    expect(NestedReplies::HotScoreQueue.size).to eq(1)
  end

  it "limits how many new refresh requests one requester can admit" do
    requester = Fabricate(:user)
    second_topic = Fabricate(:topic)
    Fabricate(:post, topic: second_topic, post_number: 1)
    Fabricate(:nested_topic, topic: second_topic)
    second_topic.update_columns(posts_count: 6)
    limiter =
      RateLimiter.new(
        requester,
        "nested-hot-score-refresh",
        1,
        1.minute,
        apply_limit_to_staff: true,
      )
    RateLimiter.enable

    stub_const(described_class, :REFRESH_REQUESTS_PER_MINUTE, 1) do
      first_decision = described_class.resolve(topic, "hot", requester: requester)
      second_decision = described_class.resolve(second_topic, "hot", requester: requester)

      expect(first_decision.enqueue_result).to eq(:queued)
      expect(second_decision.enqueue_result).to eq(:requester_limited)
      expect(NestedReplies::HotScoreQueue.size).to eq(1)
    end
  ensure
    limiter&.clear!
    RateLimiter.disable
  end

  it "uses fresh and stale snapshots while rejecting unusable snapshots" do
    fresh_topic, = create_topic_with_snapshot(calculated_at: Time.current)
    stale_topic, = create_topic_with_snapshot(calculated_at: 1.hour.ago)
    wrong_formula_topic, =
      create_topic_with_snapshot(
        calculated_at: Time.current,
        formula_version: NestedReplies::HotScoreCalculator::FORMULA_VERSION + 1,
      )
    expired_topic, = create_topic_with_snapshot(calculated_at: 31.days.ago)

    decisions =
      [fresh_topic, stale_topic, wrong_formula_topic, expired_topic].map do |cached_topic|
        described_class.resolve(cached_topic, "hot")
      end

    expect(decisions.map { |decision| [decision.effective_sort, decision.mode] }).to eq(
      [["hot", :fresh], ["hot", :stale], ["top", :wrong_formula], ["top", :expired]],
    )
    expect(NestedReplies::HotScoreQueue.size).to eq(3)
  end

  it "purges only expired cache data" do
    expired_topic, expired_post = create_topic_with_snapshot(calculated_at: 31.days.ago)
    fresh_topic, fresh_post = create_topic_with_snapshot(calculated_at: Time.current)
    orphan_topic = Fabricate(:topic)
    orphan_post = Fabricate(:post, topic: orphan_topic, post_number: 1)
    DB.exec(
      <<~SQL,
      INSERT INTO nested_hot_post_scores (post_id, topic_id, hot_score, thread_hot_score)
      VALUES (:expired_post_id, :expired_topic_id, 1.0, 2.0),
             (:fresh_post_id, :fresh_topic_id, 3.0, 4.0),
             (:orphan_post_id, :orphan_topic_id, 5.0, 6.0)
    SQL
      expired_post_id: expired_post.id,
      expired_topic_id: expired_topic.id,
      fresh_post_id: fresh_post.id,
      fresh_topic_id: fresh_topic.id,
      orphan_post_id: orphan_post.id,
      orphan_topic_id: orphan_topic.id,
    )

    result = described_class.purge_expired

    expect(result).to eq(scores_removed: 2, snapshots_removed: 1)
    expect(DB.query_single("SELECT topic_id FROM nested_hot_score_snapshots")).to eq(
      [fresh_topic.id],
    )
    expect(DB.query_single("SELECT post_id FROM nested_hot_post_scores")).to eq([fresh_post.id])
  end
end
