# frozen_string_literal: true

RSpec.describe PostMover do
  fab!(:admin)
  fab!(:source_topic) { Fabricate(:topic, user: admin) }
  fab!(:source_op) { Fabricate(:post, topic: source_topic, user: admin, post_number: 1) }
  fab!(:source_nested_topic) { Fabricate(:nested_topic, topic: source_topic) }

  fab!(:source_parent) do
    Fabricate(:post, topic: source_topic, user: admin, reply_to_post_number: source_op.post_number)
  end

  fab!(:source_child) do
    Fabricate(
      :post,
      topic: source_topic,
      user: admin,
      reply_to_post_number: source_parent.post_number,
    )
  end

  fab!(:destination_topic) { Fabricate(:topic, user: admin) }

  fab!(:destination_op) { Fabricate(:post, topic: destination_topic, user: admin, post_number: 1) }

  fab!(:destination_nested_topic) { Fabricate(:nested_topic, topic: destination_topic) }

  fab!(:destination_root) do
    Fabricate(
      :post,
      topic: destination_topic,
      user: admin,
      reply_to_post_number: destination_op.post_number,
    )
  end

  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_stats_valid_after = 0
    NestedReplies::StructuralStats.recalculate_topic(source_topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(source_topic.id)
    NestedReplies::StructuralStats.recalculate_topic(destination_topic.id)
    NestedReplies::HotScoreCalculator.recalculate_topic(destination_topic.id)
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  it "exactly rebuilds both topics after a cross-topic move", :aggregate_failures do
    source_topic.move_posts(
      admin,
      [source_parent.id, source_child.id],
      destination_topic_id: destination_topic.id,
    )

    source_marker = NestedViewPostStat.find_by!(post: source_op)
    destination_marker = NestedViewPostStat.find_by!(post: destination_op)
    expect(source_marker.structural_backfilled_at).to be_nil
    expect(source_marker.hot_score_updated_at).to be_nil
    expect(destination_marker.structural_backfilled_at).to be_nil
    expect(destination_marker.hot_score_updated_at).to be_nil

    Jobs::ProcessNestedReplyUpdates.new.execute

    moved_parent = source_parent.reload
    moved_child = source_child.reload
    expect(moved_parent.topic_id).to eq(destination_topic.id)
    expect(moved_child.topic_id).to eq(destination_topic.id)
    expect(moved_child.reply_to_post_number).to eq(moved_parent.post_number)
    expect(source_marker.reload.total_descendant_count).to eq(0)
    expect(destination_marker.reload.total_descendant_count).to eq(1)
    moved_parent_stat = NestedViewPostStat.find_by!(post: moved_parent)
    expect(moved_parent_stat.direct_reply_count).to eq(1)
    expect(moved_parent_stat.total_descendant_count).to eq(1)
    expect(source_marker.structural_backfilled_at).to be_present
    expect(source_marker.hot_score_updated_at).to be_present
    expect(destination_marker.structural_backfilled_at).to be_present
    expect(destination_marker.hot_score_updated_at).to be_present
    expect(NestedViewPostStat.find_by!(post: destination_root).hot_score_updated_at).to be_present
  end
end
