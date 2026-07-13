# frozen_string_literal: true

RSpec.describe Jobs::InvalidateNestedReplyStats do
  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_default = false
    SiteSetting.nested_replies_stats_valid_after = 0
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  def create_marked_nested_topic
    topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: topic)
    op = Fabricate(:post, topic: topic, post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(topic.id)
    [topic, op]
  end

  it "invalidates eligible topics in resumable batches", :aggregate_failures do
    first_topic, first_op = create_marked_nested_topic
    second_topic, second_op = create_marked_nested_topic
    third_topic, third_op = create_marked_nested_topic
    NestedReplies::RecalculationQueue.clear

    stub_const(described_class, :BATCH_SIZE, 2) do
      expect_enqueued_with(
        job: :invalidate_nested_reply_stats,
        args: {
          after_topic_id: second_topic.id,
        },
      ) { described_class.new.execute }
    end

    batch = NestedReplies::RecalculationQueue.pop_batch(10)
    expect(batch[:structural_topic_ids]).to contain_exactly(first_topic.id, second_topic.id)
    expect(batch[:hot_topic_ids]).to contain_exactly(first_topic.id, second_topic.id)
    expect(
      [first_op, second_op].map do |op|
        marker = NestedViewPostStat.find_by!(post: op)
        [marker.structural_backfilled_at, marker.hot_score_updated_at]
      end,
    ).to all(eq([nil, nil]))
    third_marker = NestedViewPostStat.find_by!(post: third_op)
    expect(third_marker.structural_backfilled_at).to be_present
    expect(third_marker.hot_score_updated_at).to be_present
  end

  it "includes flat topics only when nesting is the default" do
    flat_topic = Fabricate(:topic)
    flat_op = Fabricate(:post, topic: flat_topic, post_number: 1)
    Fabricate(:post, topic: flat_topic, reply_to_post_number: flat_op.post_number)
    NestedReplies::StructuralStats.recalculate_topic(flat_topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(flat_topic.id)
    NestedReplies::RecalculationQueue.clear

    described_class.new.execute
    expect(NestedReplies::RecalculationQueue.pop_batch(10).values).to all(be_empty)

    SiteSetting.nested_replies_default = true
    NestedReplies::RecalculationQueue.clear
    described_class.new.execute

    batch = NestedReplies::RecalculationQueue.pop_batch(10)
    expect(batch[:structural_topic_ids]).to eq([flat_topic.id])
    expect(batch[:hot_topic_ids]).to eq([flat_topic.id])
  end

  it "does nothing when nested replies are disabled" do
    SiteSetting.nested_replies_enabled = false

    described_class.new.execute

    expect(NestedReplies::RecalculationQueue.pop_batch(10).values).to all(be_empty)
  end
end
