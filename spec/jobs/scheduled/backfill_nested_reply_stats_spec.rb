# frozen_string_literal: true

RSpec.describe Jobs::BackfillNestedReplyStats do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before { SiteSetting.nested_replies_enabled = true }

  def execute(args = nil)
    described_class.new.execute(args)
  end

  it "does nothing when feature is disabled" do
    SiteSetting.nested_replies_enabled = false
    Fabricate(:post, topic: topic, reply_to_post_number: 1)

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

  it "stops at malformed reply cycles" do
    root = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
    root.update_columns(reply_to_post_number: child.post_number)
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by(post: root).total_descendant_count).to eq(1)
    expect(NestedViewPostStat.find_by(post: child).total_descendant_count).to eq(1)
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

  it "backfills topics nested by the site-wide default" do
    SiteSetting.nested_replies_default = true
    default_nested_topic = Fabricate(:topic)
    default_nested_op = Fabricate(:post, topic: default_nested_topic, post_number: 1)
    Fabricate(:post, topic: default_nested_topic, reply_to_post_number: 1)
    NestedViewPostStat.delete_all

    execute

    expect(default_nested_topic.nested_topic).to be_nil
    expect(NestedViewPostStat.find_by(post_id: default_nested_op.id).direct_reply_count).to eq(1)
  end

  it "does not spend backfill work on a topic with no replies" do
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by(post_id: op.id)).to be_nil
  end

  it "continues to skip reply-less topics on subsequent runs" do
    NestedViewPostStat.delete_all

    execute
    freeze_time 1.hour.from_now
    execute

    expect(NestedViewPostStat.find_by(post_id: op.id)).to be_nil
  end

  it "backfills and marks a topic after its first reply arrives" do
    NestedViewPostStat.delete_all
    execute

    Fabricate(:post, topic: topic, reply_to_post_number: 1)
    execute

    stat = NestedViewPostStat.find_by(post_id: op.id)
    expect(stat.direct_reply_count).to eq(1)
    expect(stat.total_descendant_count).to eq(1)
    expect(stat.structural_backfilled_at).to be_present
  end

  it "processes the oldest missing topics first" do
    SiteSetting.nested_replies_backfill_batch_size = 1
    newer_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: newer_topic)
    newer_op = Fabricate(:post, topic: newer_topic, post_number: 1)
    Fabricate(:post, topic: newer_topic, reply_to_post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: 1)
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by(post: op).structural_backfilled_at).to be_present
    expect(NestedViewPostStat.find_by(post: newer_op)).to be_nil
  end

  it "repairs a partial OP row created by a live reply before backfill" do
    SiteSetting.nested_replies_enabled = false
    2.times { Fabricate(:post, topic: topic, reply_to_post_number: 1) }
    SiteSetting.nested_replies_enabled = true
    Fabricate(:post, topic: topic, reply_to_post_number: 1)

    partial_stat = NestedViewPostStat.find_by!(post: op)
    expect(partial_stat.total_descendant_count).to eq(1)
    expect(partial_stat.structural_backfilled_at).to be_nil

    execute

    completed_stat = partial_stat.reload
    expect(completed_stat.total_descendant_count).to eq(3)
    expect(completed_stat.structural_backfilled_at).to be_present
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

  it "reprocesses topics with undercounted parent stats" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: 1)
    2.times { Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number) }
    execute
    NestedViewPostStat.where(post_id: parent.id).update_all(
      direct_reply_count: 1,
      total_descendant_count: 1,
    )

    execute

    stat = NestedViewPostStat.find_by!(post: parent)
    expect([stat.direct_reply_count, stat.total_descendant_count]).to eq([2, 2])
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

    expect(NestedViewPostStat.where(post_id: [op.id, other_op.id]).count).to eq(1)
  end
end
