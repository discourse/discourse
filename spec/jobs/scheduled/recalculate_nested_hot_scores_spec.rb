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

  it "does not claim ownership of a missing structural backfill marker" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by(post: op)).to be_nil

    backfill_structural_stats
    expect(NestedViewPostStat.find_by(post: op).total_descendant_count).to eq(2)

    execute
    expect(NestedViewPostStat.find_by(post: parent).hot_score_updated_at).to be_present
  end

  it "refreshes scores older than seven days", :aggregate_failures do
    post = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    set_hot_score_inputs(post, created_at: 1.day.ago)
    backfill_structural_stats
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    stat = NestedViewPostStat.find_by!(post: post)
    topic_marker = NestedViewPostStat.find_by!(post: op)
    stale_updated_at = 8.days.ago
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
end
