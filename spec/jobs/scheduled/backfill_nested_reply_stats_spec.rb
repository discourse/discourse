# frozen_string_literal: true

RSpec.describe Jobs::BackfillNestedReplyStats do
  fab!(:topic)
  fab!(:op) { Fabricate(:post, topic: topic, post_number: 1) }
  fab!(:nested_topic) { Fabricate(:nested_topic, topic: topic) }

  before do
    SiteSetting.nested_replies_enabled = true
    NestedReplies::RecalculationQueue.clear
  end

  after { NestedReplies::RecalculationQueue.clear }

  def execute(args = nil)
    described_class.new.execute(args)
  end

  def structural_counts(stat)
    stat.attributes.slice(
      "direct_reply_count",
      "total_descendant_count",
      "whisper_direct_reply_count",
      "whisper_total_descendant_count",
    )
  end

  it "does nothing when the feature is disabled" do
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedViewPostStat.delete_all
    SiteSetting.nested_replies_enabled = false

    execute

    expect(NestedViewPostStat.count).to eq(0)
  end

  it "exactly rebuilds structural counts", :aggregate_failures do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      post_type: Post.types[:moderator_action],
    )
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      post_type: Post.types[:whisper],
    )
    small_action = Fabricate(:small_action, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: small_action.post_number)

    parent_stat = NestedViewPostStat.find_by!(post: parent)
    parent_stat.update_columns(
      direct_reply_count: 999,
      total_descendant_count: 1,
      whisper_direct_reply_count: 99,
      whisper_total_descendant_count: 0,
    )

    execute

    expect(structural_counts(parent_stat.reload)).to eq(
      "direct_reply_count" => 3,
      "total_descendant_count" => 4,
      "whisper_direct_reply_count" => 1,
      "whisper_total_descendant_count" => 1,
    )
    expect(NestedViewPostStat.find_by!(post: small_action).total_descendant_count).to eq(1)
    expect(NestedViewPostStat.find_by!(post: op).structural_backfilled_at).to be_present
  end

  it "excludes action-code whispers from structural counts", :aggregate_failures do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      post_type: Post.types[:whisper],
    )
    action_whisper =
      Fabricate(
        :post,
        topic: topic,
        reply_to_post_number: parent.post_number,
        post_type: Post.types[:whisper],
        action_code: "assigned",
      )
    action_child = Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    action_child.update_columns(reply_to_post_number: action_whisper.post_number)

    execute

    parent_stat = NestedViewPostStat.find_by!(post: parent)
    expect(structural_counts(parent_stat)).to eq(
      "direct_reply_count" => 2,
      "total_descendant_count" => 3,
      "whisper_direct_reply_count" => 1,
      "whisper_total_descendant_count" => 1,
    )
  end

  it "rebuilds a chain beyond the old recursive cutoff in batches" do
    now = Time.current
    rows =
      (2..1006).map do |post_number|
        {
          topic_id: topic.id,
          user_id: op.user_id,
          post_number: post_number,
          reply_to_post_number: post_number - 1,
          post_type: Post.types[:regular],
          raw: "Deep reply #{post_number}",
          cooked: "<p>Deep reply #{post_number}</p>",
          sort_order: post_number,
          created_at: now,
          updated_at: now,
          last_version_at: now,
        }
      end
    Post.insert_all!(rows)
    NestedViewPostStat.delete_all

    execute

    first_reply = Post.find_by!(topic: topic, post_number: 2)
    expect(NestedViewPostStat.find_by!(post: op).total_descendant_count).to eq(1005)
    expect(NestedViewPostStat.find_by!(post: first_reply).total_descendant_count).to eq(1004)
    expect(NestedViewPostStat.where(post_id: topic.posts.select(:id)).count).to eq(1006)
  end

  it "includes soft-deleted posts" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(
      :post,
      topic: topic,
      reply_to_post_number: parent.post_number,
      deleted_at: Time.current,
    )
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by!(post: parent).direct_reply_count).to eq(1)
  end

  it "stops at malformed reply cycles" do
    root = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    child = Fabricate(:post, topic: topic, reply_to_post_number: root.post_number)
    root.update_columns(reply_to_post_number: child.post_number)
    NestedViewPostStat.delete_all

    execute

    expect(
      [
        NestedViewPostStat.find_by!(post: root).total_descendant_count,
        NestedViewPostStat.find_by!(post: child).total_descendant_count,
      ],
    ).to eq([1, 1])
  end

  it "backfills an explicitly requested reply-less topic" do
    NestedViewPostStat.delete_all

    execute(topic_id: topic.id)

    stat = NestedViewPostStat.find_by!(post: op)
    expect(structural_counts(stat)).to eq(
      "direct_reply_count" => 0,
      "total_descendant_count" => 0,
      "whisper_direct_reply_count" => 0,
      "whisper_total_descendant_count" => 0,
    )
    expect(stat.structural_backfilled_at).to be_present
  end

  it "skips an explicitly requested flat topic" do
    flat_topic = Fabricate(:topic)
    flat_op = Fabricate(:post, topic: flat_topic, post_number: 1)

    execute(topic_id: flat_topic.id)

    expect(NestedViewPostStat.find_by(post: flat_op)).to be_nil
  end

  it "backfills an explicit topic nested by the default" do
    SiteSetting.nested_replies_default = true
    default_topic = Fabricate(:topic)
    default_op = Fabricate(:post, topic: default_topic, post_number: 1)

    execute(topic_id: default_topic.id)

    expect(default_topic.nested_topic).to be_nil
    expect(NestedViewPostStat.find_by!(post: default_op).structural_backfilled_at).to be_present
  end

  it "skips reply-less topics during the initial scan" do
    NestedViewPostStat.delete_all

    execute

    expect(NestedViewPostStat.find_by(post: op)).to be_nil
  end

  it "only scans topics with a missing or stale marker" do
    parent = Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    Fabricate(:post, topic: topic, reply_to_post_number: parent.post_number)
    execute
    NestedViewPostStat.where(post: parent).delete_all
    op_stat = NestedViewPostStat.find_by!(post: op)
    op_stat.update_columns(direct_reply_count: 999)

    execute

    expect(NestedViewPostStat.find_by(post: parent)).to be_nil
    expect(op_stat.reload.direct_reply_count).to eq(999)

    SiteSetting.nested_replies_stats_valid_after = op_stat.structural_backfilled_at.to_f + 1
    execute

    expect(NestedViewPostStat.find_by(post: parent)).to be_present
    expect(op_stat.reload.direct_reply_count).to eq(1)
  end

  it "limits the initial scan to one category" do
    category = Fabricate(:category)
    other_category = Fabricate(:category)
    category_topic = Fabricate(:topic, category: category)
    other_topic = Fabricate(:topic, category: other_category)
    Fabricate(:nested_topic, topic: category_topic)
    Fabricate(:nested_topic, topic: other_topic)
    category_op = Fabricate(:post, topic: category_topic, post_number: 1)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: category_topic, reply_to_post_number: category_op.post_number)
    Fabricate(:post, topic: other_topic, reply_to_post_number: other_op.post_number)
    NestedViewPostStat.delete_all

    execute(category_id: category.id)

    expect(NestedViewPostStat.exists?(post: category_op)).to eq(true)
    expect(NestedViewPostStat.exists?(post: other_op)).to eq(false)
  end

  it "continues a full batch from the last topic" do
    SiteSetting.nested_replies_backfill_batch_size = 1
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    later_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: later_topic)
    later_op = Fabricate(:post, topic: later_topic, post_number: 1)
    Fabricate(:post, topic: later_topic, reply_to_post_number: later_op.post_number)
    NestedViewPostStat.delete_all

    expect_enqueued_with(
      job: :backfill_nested_reply_stats,
      args: {
        after_topic_id: topic.id,
        drain_batch: 2,
      },
    ) { execute }

    expect(NestedViewPostStat.exists?(post: op)).to eq(true)
    expect(NestedViewPostStat.exists?(post: later_op)).to eq(false)
  end

  it "caps a structural drain chain", :aggregate_failures do
    SiteSetting.nested_replies_backfill_batch_size = 1
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    NestedViewPostStat.delete_all
    described_class.jobs.clear

    execute(drain_batch: described_class::MAX_DRAIN_BATCHES)

    expect(NestedViewPostStat.find_by!(post: op).structural_backfilled_at).to be_present
    expect(described_class.jobs).to be_empty
  end

  it "isolates a failed topic and stops the chain", :aggregate_failures do
    SiteSetting.nested_replies_backfill_batch_size = 2
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)
    other_topic = Fabricate(:topic)
    Fabricate(:nested_topic, topic: other_topic)
    other_op = Fabricate(:post, topic: other_topic, post_number: 1)
    Fabricate(:post, topic: other_topic, reply_to_post_number: other_op.post_number)
    NestedViewPostStat.delete_all
    described_class.jobs.clear
    allow(Discourse).to receive(:warn_exception)
    allow(NestedReplies::StructuralStats).to receive(
      :recalculate_topic,
    ).and_wrap_original do |method, topic_id|
      raise StandardError, "poison topic" if topic_id == topic.id

      method.call(topic_id)
    end

    execute

    expect(NestedViewPostStat.find_by(post: op)).to be_nil
    expect(NestedViewPostStat.find_by!(post: other_op).structural_backfilled_at).to be_present
    expect(described_class.jobs).to be_empty
  end
end
