# frozen_string_literal: true

RSpec.describe Jobs::RecalculateNestedHotScores do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute(args = nil)
    described_class.new.execute(args)
  end

  def set_hot_score_inputs(post, created_at:, like_score: 0)
    post.update_columns(created_at: created_at, like_score: like_score)
  end

  def backfill_structural_stats
    Jobs::BackfillNestedReplyStats.new.execute
  end

  it "does nothing when nested replies are disabled" do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedViewPostStat.delete_all
    SiteSetting.nested_replies_enabled = false

    execute

    expect(NestedViewPostStat.find_by(post_id: post.id)).to be_nil
  end

  it "backfills missing scores with propagated heat", :aggregate_failures do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    set_hot_score_inputs(parent, created_at: 1.day.ago)
    set_hot_score_inputs(child, created_at: 12.hours.ago, like_score: 20)
    NestedViewPostStat.delete_all
    backfill_structural_stats

    execute

    parent_stat = NestedViewPostStat.find_by!(post: parent)
    child_stat = NestedViewPostStat.find_by!(post: child)
    expect(child_stat.hot_score_updated_at).to be_present
    expect(parent_stat.thread_hot_score).to be_within(0.0001).of(
      child_stat.thread_hot_score - NestedReplies::HotScoreCalculator.child_penalty,
    )
    expect(parent_stat.thread_hot_score).to be > parent_stat.hot_score
  end

  it "backfills hot scores without claiming the structural marker", :aggregate_failures do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    NestedViewPostStat.delete_all

    execute

    topic_marker = NestedViewPostStat.find_by!(post: op)
    expect(topic_marker.hot_score_updated_at).to be_present
    expect(topic_marker.structural_backfilled_at).to be_nil
    expect(NestedViewPostStat.find_by(post: parent).hot_score_updated_at).to be_present
  end

  it "refreshes decaying scores after six hours", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    set_hot_score_inputs(post, created_at: 1.day.ago)
    topic.update_columns(last_posted_at: 1.day.ago)
    backfill_structural_stats
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    stat = NestedViewPostStat.find_by!(post: post)
    topic_marker = NestedViewPostStat.find_by!(post: op)
    stale_updated_at = 7.hours.ago
    topic_marker.update_columns(hot_score_updated_at: stale_updated_at)
    post.update_columns(like_score: 10)

    execute

    expect(topic_marker.reload.hot_score_updated_at).to be > stale_updated_at
    expect(stat.reload.hot_score).to be_within(0.0001).of(
      NestedReplies::HotScoreCalculator.score_for(post.reload),
    )
  end

  it "leaves fresh scores unchanged", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    set_hot_score_inputs(post, created_at: 1.day.ago, like_score: 3)
    backfill_structural_stats
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    topic_marker = NestedViewPostStat.find_by!(post: op)
    original_updated_at = topic_marker.updated_at
    original_hot_score_updated_at = topic_marker.hot_score_updated_at

    execute

    expect(topic_marker.reload.updated_at).to eq_time(original_updated_at)
    expect(topic_marker.hot_score_updated_at).to eq_time(original_hot_score_updated_at)
  end

  it "replaces scores from the previous formula", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    backfill_structural_stats
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    TopicCustomField.where(
      topic_id: topic.id,
      name: NestedReplies::HotScoreCalculator::FORMULA_VERSION_FIELD,
    ).delete_all
    stat = NestedViewPostStat.find_by!(post: post)
    stat.update_columns(
      hot_score: NestedReplies::HotScoreCalculator::LEGACY_SCORE_THRESHOLD + 1,
      thread_hot_score: NestedReplies::HotScoreCalculator::LEGACY_SCORE_THRESHOLD + 1,
    )

    execute

    expect(stat.reload.hot_score).to be < NestedReplies::HotScoreCalculator::LEGACY_SCORE_THRESHOLD
    expect(
      topic.reload.custom_fields[NestedReplies::HotScoreCalculator::FORMULA_VERSION_FIELD],
    ).to eq(NestedReplies::HotScoreCalculator::FORMULA_VERSION.to_s)
  end

  it "refreshes a cooled topic once", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    cooled_at = Time.current - NestedReplies::HotScoreCalculator.freshness_window_seconds - 1.day
    set_hot_score_inputs(post, created_at: cooled_at)
    topic.update_columns(last_posted_at: cooled_at)
    backfill_structural_stats
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    topic_marker = NestedViewPostStat.find_by!(post: op)
    topic_marker.update_columns(hot_score_updated_at: cooled_at)

    execute
    final_refresh_at = topic_marker.reload.hot_score_updated_at
    execute

    expect(final_refresh_at).to be > cooled_at
    expect(topic_marker.reload.hot_score_updated_at).to eq_time(final_refresh_at)
  end

  it "backfills topics nested by the global default" do
    SiteSetting.nested_replies_default = true
    default_nested_topic = Fabricate(:topic)
    default_nested_op = Fabricate(:post, topic: default_nested_topic, post_number: 1)
    post =
      Fabricate(
        :post,
        topic: default_nested_topic,
        reply_to_post_number: default_nested_op.post_number,
      )
    backfill_structural_stats
    NestedViewPostStat.where(post_id: post.id).delete_all

    execute

    expect(default_nested_topic.nested_topic).to be_nil
    expect(NestedViewPostStat.find_by(post: post).hot_score_updated_at).to be_present
  end

  it "recalculates an explicitly requested topic" do
    flat_topic = Fabricate(:topic)
    flat_op = Fabricate(:post, topic: flat_topic, post_number: 1)
    post = Fabricate(:post, topic: flat_topic, reply_to_post_number: flat_op.post_number)
    NestedViewPostStat.where(post_id: post.id).delete_all

    execute(topic_id: flat_topic.id)

    expect(NestedViewPostStat.find_by(post: post).hot_score_updated_at).to be_present
  end

  it "limits a scheduled run to the requested category" do
    category = Fabricate(:category)
    other_category = Fabricate(:category)
    category_topic = Fabricate(:topic, category: category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:nested_topic, topic: category_topic)
    Fabricate(:nested_topic, topic: other_topic)
    category_op = Fabricate(:post, topic: category_topic, post_number: 1)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    category_post =
      Fabricate(:post, topic: category_topic, reply_to_post_number: category_op.post_number)
    other_post = Fabricate(:post, topic: other_topic, reply_to_post_number: other_op.post_number)
    NestedViewPostStat.delete_all

    execute(category_id: category.id)

    expect(NestedViewPostStat.find_by(post: category_post).hot_score_updated_at).to be_present
    expect(NestedViewPostStat.find_by(post: other_post)).to be_nil
  end

  it "continues a full hot-score batch" do
    SiteSetting.nested_replies_backfill_batch_size = 20
    SiteSetting.nested_replies_hot_score_batch_size = 1
    first_post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    other_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: other_topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    other_post = Fabricate(:post, topic: other_topic, reply_to_post_number: other_op.post_number)
    NestedViewPostStat.delete_all

    expect_enqueued_with(job: :recalculate_nested_hot_scores, args: { drain_batch: 2 }) { execute }

    expect(
      NestedViewPostStat
        .where(post_id: [first_post.id, other_post.id])
        .where.not(hot_score_updated_at: nil)
        .count,
    ).to eq(1)
  end

  it "caps a hot-score drain chain", :aggregate_failures do
    SiteSetting.nested_replies_hot_score_batch_size = 1
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedViewPostStat.delete_all
    described_class.jobs.clear

    execute(drain_batch: described_class::MAX_DRAIN_BATCHES)

    expect(NestedViewPostStat.find_by!(post: post).hot_score_updated_at).to be_present
    expect(described_class.jobs).to be_empty
  end

  it "isolates a failed topic and stops the chain", :aggregate_failures do
    SiteSetting.nested_replies_hot_score_batch_size = 2
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    other_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: other_topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    other_post = Fabricate(:post, topic: other_topic, reply_to_post_number: other_op.post_number)
    NestedViewPostStat.delete_all
    described_class.jobs.clear
    allow(Discourse).to receive(:warn_exception)
    allow(NestedReplies::HotScoreCalculator).to receive(
      :recalculate_topic,
    ).and_wrap_original do |method, topic_id|
      raise StandardError, "poison topic" if topic_id == topic.id

      method.call(topic_id)
    end

    execute

    expect(NestedViewPostStat.find_by(post: op)).to be_nil
    expect(NestedViewPostStat.find_by!(post: other_post).hot_score_updated_at).to be_present
    expect(described_class.jobs).to be_empty
  end
end
