# frozen_string_literal: true

RSpec.describe Jobs::ReconcileNestedReplyStats do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute
    described_class.new.execute
  end

  it "does nothing when the feature is disabled" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    stat = NestedViewPostStat.find_by!(post: parent)
    stat.update_columns(direct_reply_count: 999)
    SiteSetting.nested_replies_enabled = false

    execute

    expect(stat.reload.direct_reply_count).to eq(999)
  end

  it "repairs missing, overcounted, and undercounted stats", :aggregate_failures do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    first_child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    NestedReplies::StructuralStats.recalculate_topic(topic.id)
    parent_stat = NestedViewPostStat.find_by!(post: parent)
    parent_stat.update_columns(direct_reply_count: 999, total_descendant_count: 1)
    NestedViewPostStat.where(post: first_child).delete_all

    execute

    expect(parent_stat.reload.direct_reply_count).to eq(2)
    expect(parent_stat.total_descendant_count).to eq(2)
    expect(NestedViewPostStat.find_by(post: first_child)).to be_present
  end

  it "only reconciles topics with a completion marker" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    NestedViewPostStat.where(post: parent).delete_all

    execute

    expect(NestedViewPostStat.find_by(post: parent)).to be_nil
  end

  it "rotates through the oldest completed topics" do
    SiteSetting.nested_replies_reconciliation_batch_size = 1
    older_parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: older_parent.post_number)
    NestedReplies::StructuralStats.recalculate_topic(topic.id)

    newer_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: newer_topic)
    newer_op = Fabricate(:post, topic: newer_topic, post_number: 1)
    newer_parent = Fabricate(:post, topic: newer_topic, reply_to_post_number: newer_op.post_number)
    Fabricate(:post, topic: newer_topic, reply_to_post_number: newer_parent.post_number)
    NestedReplies::StructuralStats.recalculate_topic(newer_topic.id)

    older_marker = NestedViewPostStat.find_by!(post: op)
    newer_marker = NestedViewPostStat.find_by!(post: newer_op)
    older_marker.update_columns(structural_backfilled_at: 2.hours.ago)
    newer_marker.update_columns(structural_backfilled_at: 1.hour.ago)

    older_stat = NestedViewPostStat.find_by!(post: older_parent)
    newer_stat = NestedViewPostStat.find_by!(post: newer_parent)
    older_stat.update_columns(direct_reply_count: 999)
    newer_stat.update_columns(direct_reply_count: 999)

    execute

    expect(older_stat.reload.direct_reply_count).to eq(1)
    expect(newer_stat.reload.direct_reply_count).to eq(999)

    older_marker.update_columns(structural_backfilled_at: Time.current)
    execute

    expect(newer_stat.reload.direct_reply_count).to eq(1)
  end

  it "reconciles topics nested by the global default" do
    SiteSetting.nested_replies_default = true
    default_topic = Fabricate(:topic)
    default_op = Fabricate(:post, topic: default_topic, post_number: 1)
    parent = Fabricate(:post, topic: default_topic, reply_to_post_number: default_op.post_number)
    Fabricate(:post, topic: default_topic, reply_to_post_number: parent.post_number)
    NestedReplies::StructuralStats.recalculate_topic(default_topic.id)
    stat = NestedViewPostStat.find_by!(post: parent)
    stat.update_columns(total_descendant_count: 999)

    execute

    expect(default_topic.nested_topic).to be_nil
    expect(stat.reload.total_descendant_count).to eq(1)
  end
end
