# frozen_string_literal: true

RSpec.describe Jobs::ProcessNestedReplyUpdates do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }
  fab!(:parent) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }
  fab!(:child) { Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number) }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_stats_valid_after = 0
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  def execute
    described_class.new.execute
  end

  it "drains exact structural and hot topic rebuilds", :aggregate_failures do
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    parent_stat = NestedViewPostStat.find_by!(post: parent)
    parent_stat.update_columns(direct_reply_count: 999, hot_score: -1, thread_hot_score: -1)

    NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
      [topic.id],
      structural: true,
      hot: true,
    )
    execute

    marker = NestedViewPostStat.find_by!(post: op)
    expect(parent_stat.reload.direct_reply_count).to eq(1)
    expect(parent_stat.hot_score).to be >= 0
    expect(parent_stat.thread_hot_score).to be >= parent_stat.hot_score
    expect(marker.structural_backfilled_at).to be_present
    expect(marker.hot_score_updated_at).to be_present
    expect(NestedReplies::RecalculationQueue.pop_batch(10).values).to all(be_empty)
  end

  it "isolates structural failures and permits a retry", :aggregate_failures do
    healthy_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: healthy_topic)
    healthy_op = Fabricate(:post, topic: healthy_topic, post_number: 1)
    Fabricate(:post, topic: healthy_topic, reply_to_post_number: healthy_op.post_number)
    allow(Discourse).to receive(:warn_exception)
    allow(NestedReplies::StructuralStats).to receive(
      :recalculate_topic,
    ).and_wrap_original do |method, topic_id|
      raise StandardError, "poison topic" if topic_id == topic.id

      method.call(topic_id)
    end

    NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
      [topic.id, healthy_topic.id],
      structural: true,
      hot: false,
    )
    execute

    expect(NestedViewPostStat.find_by(post: op)&.structural_backfilled_at).to be_nil
    expect(NestedViewPostStat.find_by!(post: healthy_op).structural_backfilled_at).to be_present

    allow(NestedReplies::StructuralStats).to receive(:recalculate_topic).and_call_original
    NestedReplies::RecalculationQueue.enqueue_topic_rebuilds(
      [topic.id],
      structural: true,
      hot: false,
    )
    execute

    expect(NestedViewPostStat.find_by!(post: op).structural_backfilled_at).to be_present
  end

  it "invalidates a failed hot marker and recovers on retry", :aggregate_failures do
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    original_score = NestedViewPostStat.find_by!(post: child).hot_score
    child.update_columns(like_score: 50)
    NestedReplies::RecalculationQueue.clear
    NestedReplies::RecalculationQueue.enqueue_hot_post(child.id)
    allow(Discourse).to receive(:warn_exception)
    allow(NestedReplies::HotScoreCalculator).to receive(:recalculate_posts_for_topic).and_raise(
      StandardError,
      "score failure",
    )

    execute

    expect(NestedViewPostStat.find_by!(post: op).hot_score_updated_at).to be_nil
    expect(NestedViewPostStat.find_by!(post: child).hot_score).to eq(original_score)

    allow(NestedReplies::HotScoreCalculator).to receive(
      :recalculate_posts_for_topic,
    ).and_call_original
    NestedReplies::RecalculationQueue.enqueue_hot_post(child.id)
    execute

    expect(NestedViewPostStat.find_by!(post: op).hot_score_updated_at).to be_present
    expect(NestedViewPostStat.find_by!(post: child).hot_score).to be > original_score
  end
end
