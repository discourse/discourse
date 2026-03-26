# frozen_string_literal: true

RSpec.describe Jobs::BackfillNestedReplyStats do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute(args = {})
    described_class.new.execute(args)
  end

  it "does nothing when feature is disabled" do
    SiteSetting.nested_replies_enabled = false
    Fabricate(:post, topic: topic, reply_to_post_number: 1)

    execute(from_topic_id: 0)

    expect(NestedViewPostStat.count).to eq(0)
  end

  it "computes direct_reply_count for a parent with replies" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    3.times { Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number) }

    NestedViewPostStat.delete_all
    execute(from_topic_id: 0)

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(3)
  end

  it "computes total_descendant_count across multiple depths" do
    root = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: child.post_number)

    NestedViewPostStat.delete_all
    execute(from_topic_id: 0)

    stat = NestedViewPostStat.find_by(post_id: root.id)
    expect(stat.direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(2)
  end

  it "tracks whisper counts separately" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      post_type: Post.types[:whisper],
    )

    NestedViewPostStat.delete_all
    execute(from_topic_id: 0)

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(2)
    expect(stat.whisper_direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(2)
    expect(stat.whisper_total_descendant_count).to eq(1)
  end

  it "skips deleted posts" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      deleted_at: Time.current,
    )

    NestedViewPostStat.delete_all
    execute(from_topic_id: 0)

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(1)
  end

  it "overwrites existing stale stats via upsert" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)

    NestedViewPostStat.delete_all
    NestedViewPostStat.create!(
      post_id: parent.id,
      direct_reply_count: 999,
      total_descendant_count: 999,
    )

    execute(from_topic_id: 0)

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(1)
  end

  it "processes multiple topics across batches" do
    other_topic = Fabricate(:topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: other_topic, reply_to_post_number: 1)

    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)

    NestedViewPostStat.delete_all
    execute(from_topic_id: 0)

    expect(NestedViewPostStat.find_by(post_id: other_op.id).direct_reply_count).to eq(1)
    expect(NestedViewPostStat.find_by(post_id: parent.id).direct_reply_count).to eq(1)
  end

  it "re-enqueues itself for the next batch" do
    NestedViewPostStat.delete_all
    expect_enqueued_with(job: :backfill_nested_reply_stats) { execute(from_topic_id: 0) }
  end

  it "does not re-enqueue when no topics remain" do
    NestedViewPostStat.delete_all
    very_high_id = Topic.maximum(:id).to_i + 1_000_000

    expect_not_enqueued_with(job: :backfill_nested_reply_stats) do
      execute(from_topic_id: very_high_id)
    end
  end
end
