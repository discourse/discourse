# frozen_string_literal: true

RSpec.describe Jobs::BackfillNestedReplyStats do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute(args = nil)
    described_class.new.execute(args)
  end

  it "does nothing when feature is disabled, even during explicit preparation" do
    SiteSetting.nested_replies_enabled = false
    Fabricate(:post, topic: topic, reply_to_post_number: 1)
    SiteSetting.nested_replies_stats_maintenance_enabled = true

    execute

    expect(NestedViewPostStat.count).to eq(0)
  end

  it "computes direct_reply_count for a parent with replies" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    3.times { Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number) }

    NestedViewPostStat.delete_all
    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(3)
  end

  it "computes total_descendant_count across multiple depths" do
    root = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: child.post_number)

    NestedViewPostStat.delete_all
    execute

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
    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(2)
    expect(stat.whisper_direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(2)
    expect(stat.whisper_total_descendant_count).to eq(1)
  end

  it "includes soft-deleted posts in stats" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      deleted_at: Time.current,
    )

    NestedViewPostStat.delete_all
    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(2)
  end

  it "preserves higher live-incremented stats over backfill-computed values" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)

    NestedViewPostStat.delete_all
    NestedViewPostStat.create!(
      post_id: parent.id,
      direct_reply_count: 999,
      total_descendant_count: 999,
      whisper_direct_reply_count: 50,
      whisper_total_descendant_count: 50,
    )

    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(999)
    expect(stat.total_descendant_count).to eq(999)
    expect(stat.whisper_direct_reply_count).to eq(50)
    expect(stat.whisper_total_descendant_count).to eq(50)
  end

  it "updates stats when backfill computes higher values than existing" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    3.times { Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number) }

    NestedViewPostStat.delete_all
    NestedViewPostStat.create!(post_id: parent.id, direct_reply_count: 1, total_descendant_count: 1)

    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(3)
    expect(stat.total_descendant_count).to eq(3)
  end

  it "processes multiple topics" do
    other_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: other_topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: other_topic, reply_to_post_number: 1)

    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)

    NestedViewPostStat.delete_all
    execute

    expect(NestedViewPostStat.find_by(post_id: other_op.id).direct_reply_count).to eq(1)
    expect(NestedViewPostStat.find_by(post_id: parent.id).direct_reply_count).to eq(1)
  end

  it "skips topics without a nested_topic record" do
    non_nested_topic = Fabricate(:topic)
    non_nested_op = Fabricate(:post, topic: non_nested_topic, post_number: 1)
    Fabricate(:post, topic: non_nested_topic, reply_to_post_number: 1)

    NestedViewPostStat.delete_all
    execute

    expect(NestedViewPostStat.find_by(post_id: non_nested_op.id)).to be_nil
  end

  it "processes topics without a record when nested replies are the default" do
    SiteSetting.nested_replies_default = true
    topic.nested_topic.destroy!
    reply = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: reply.post_number)

    NestedViewPostStat.delete_all
    execute

    expect(NestedViewPostStat.find_by(post_id: reply.id).direct_reply_count).to eq(1)
  end

  it "inserts a zero-count sentinel row for the OP of a topic with no replies" do
    NestedViewPostStat.delete_all

    execute

    stat = NestedViewPostStat.find_by(post_id: op.id)
    expect(stat).to be_present
    expect(stat.direct_reply_count).to eq(0)
    expect(stat.total_descendant_count).to eq(0)
    expect(stat.whisper_direct_reply_count).to eq(0)
    expect(stat.whisper_total_descendant_count).to eq(0)
  end

  it "does not re-pick reply-less topics on subsequent runs" do
    NestedViewPostStat.delete_all

    execute
    initial_updated_at = NestedViewPostStat.find_by(post_id: op.id).updated_at

    freeze_time 1.hour.from_now
    execute
    expect(NestedViewPostStat.find_by(post_id: op.id).updated_at).to eq_time(initial_updated_at)
  end

  it "lets a later reply increment the sentinel row via ON CONFLICT" do
    NestedViewPostStat.delete_all
    execute

    Fabricate(:post, topic: topic, reply_to_post_number: 1)

    stat = NestedViewPostStat.find_by(post_id: op.id)
    expect(stat.direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(1)
  end

  it "only picks up topics with missing stats" do
    Fabricate(:post, topic: topic, reply_to_post_number: 1)

    execute
    initial_updated_at = NestedViewPostStat.find_by(post_id: op.id).updated_at

    freeze_time 1.hour.from_now
    execute
    expect(NestedViewPostStat.find_by(post_id: op.id).updated_at).to eq_time(initial_updated_at)
  end

  it "reprocesses topics with missing non-OP stats" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)

    execute
    NestedViewPostStat.where(post_id: parent.id).delete_all
    execute

    stat = NestedViewPostStat.find_by(post_id: parent.id)
    expect(stat.direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(1)
  end

  it "limits backfill to the requested category" do
    category = Fabricate(:category)
    other_category = Fabricate(:category)
    category_topic = Fabricate(:topic, category: category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:nested_topic, topic: category_topic)
    Fabricate(:nested_topic, topic: other_topic)
    category_op = Fabricate(:post, topic: category_topic, post_number: 1)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: category_topic, reply_to_post_number: 1)
    Fabricate(:post, topic: other_topic, reply_to_post_number: 1)

    NestedViewPostStat.delete_all
    execute(category_id: category.id)

    expect(NestedViewPostStat.exists?(post_id: category_op.id)).to eq(true)
    expect(NestedViewPostStat.exists?(post_id: other_op.id)).to eq(false)
  end

  it "respects the configured batch size" do
    other_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: other_topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: other_topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: 1)
    SiteSetting.nested_replies_backfill_batch_size = 1

    NestedViewPostStat.delete_all
    execute

    expect(NestedViewPostStat.exists?(post_id: other_op.id)).to eq(true)
    expect(NestedViewPostStat.exists?(post_id: op.id)).to eq(false)
  end
end
