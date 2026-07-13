# frozen_string_literal: true

RSpec.describe NestedReplies::RecalculationQueue do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }
  fab!(:post) { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_stats_valid_after = 0
    described_class.clear
    Jobs::ProcessNestedReplyUpdates.jobs.clear
  end

  after { described_class.clear }

  it "deduplicates rebuilds and invalidates topic markers", :aggregate_failures do
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    child_hot_marker = NestedViewPostStat.find_by!(post: post).hot_score_updated_at
    described_class.clear

    described_class.enqueue_topic_rebuilds([topic.id], structural: true, hot: true)
    described_class.enqueue_topic_rebuilds([topic.id], structural: true, hot: true)

    batch = described_class.pop_batch(10)
    topic_marker = NestedViewPostStat.find_by!(post: op)
    expect(batch[:structural_topic_ids]).to eq([topic.id])
    expect(batch[:hot_topic_ids]).to eq([topic.id])
    expect(batch[:hot_post_ids]).to be_empty
    expect(topic_marker.structural_backfilled_at).to be_nil
    expect(topic_marker.hot_score_updated_at).to be_nil
    expect(NestedViewPostStat.find_by!(post: post).hot_score_updated_at).to eq_time(
      child_hot_marker,
    )
    expect(Jobs::ProcessNestedReplyUpdates.jobs.size).to eq(1)
  end

  it "invalidates markers when Redis cannot accept a rebuild", :aggregate_failures do
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    allow(Discourse.redis).to receive(:sadd).and_return(nil)

    result = described_class.enqueue_topic_rebuilds([topic.id], structural: true, hot: true)

    marker = NestedViewPostStat.find_by!(post: op)
    expect(result).to eq([topic.id])
    expect(marker.structural_backfilled_at).to be_nil
    expect(marker.hot_score_updated_at).to be_nil
    expect(Jobs::ProcessNestedReplyUpdates.jobs).to be_empty
  end

  it "queues only eligible public replies" do
    flat_topic = Fabricate(:topic)
    flat_op = Fabricate(:post, topic: flat_topic, post_number: 1)
    flat_post = Fabricate(:post, topic: flat_topic, reply_to_post_number: flat_op.post_number)
    whisper =
      Fabricate(
        :post,
        topic: topic,
        reply_to_post_number: op.post_number,
        post_type: Post.types[:whisper],
      )
    described_class.clear

    described_class.enqueue_hot_post_if_nested(post.id)
    described_class.enqueue_hot_post_if_nested(flat_post.id)
    described_class.enqueue_hot_post_if_nested(whisper.id)

    expect(described_class.pop_batch(10)[:hot_post_ids]).to eq([post.id])
  end

  it "recovers an abandoned hot-post claim exactly once", :aggregate_failures do
    described_class.enqueue_hot_post(post.id)

    first_claim = described_class.pop_batch(10)
    duplicate_claim = described_class.pop_batch(10)
    recovered_count = described_class.recover_hot_posts
    recovered_claim = described_class.pop_batch(10)
    described_class.acknowledge_hot_posts(recovered_claim[:hot_post_ids])

    expect(first_claim[:hot_post_ids]).to eq([post.id])
    expect(duplicate_claim[:hot_post_ids]).to be_empty
    expect(recovered_count).to eq(1)
    expect(recovered_claim[:hot_post_ids]).to eq([post.id])
    expect(described_class.recover_hot_posts).to eq(0)
    expect(described_class.pop_batch(10)[:hot_post_ids]).to be_empty
    expect(described_class.finish).to eq(false)
  end
end
