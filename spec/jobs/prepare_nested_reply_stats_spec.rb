# frozen_string_literal: true

RSpec.describe Jobs::PrepareNestedReplyStats do
  before do
    SiteSetting.nested_replies_enabled = false
    SiteSetting.nested_replies_default = false
    SiteSetting.nested_replies_stats_maintenance_enabled = false
  end

  it "prepares every regular topic while nested replies remain disabled" do
    topic = Fabricate(:topic)
    op = Fabricate(:post, topic: topic, post_number: 1)
    Fabricate(:post, topic: topic, reply_to_post_number: op.post_number)

    deleted_topic = Fabricate(:topic, deleted_at: Time.current)
    deleted_op = Fabricate(:post, topic: deleted_topic, post_number: 1)

    private_message = Fabricate(:private_message_topic)
    private_message_op = Fabricate(:post, topic: private_message, post_number: 1)

    described_class.new.execute(max_topic_id: Topic.maximum(:id))

    expect(NestedViewPostStat.find_by(post_id: op.id)).to have_attributes(
      direct_reply_count: 1,
      total_descendant_count: 1,
    )
    expect(NestedViewPostStat.exists?(post_id: deleted_op.id)).to eq(false)
    expect(NestedViewPostStat.exists?(post_id: private_message_op.id)).to eq(false)
  end

  it "immediately continues from the last topic in each bounded batch" do
    after_topic_id = Topic.maximum(:id).to_i
    first_topic = Fabricate(:topic)
    first_op = Fabricate(:post, topic: first_topic, post_number: 1)
    second_topic = Fabricate(:topic)
    second_op = Fabricate(:post, topic: second_topic, post_number: 1)
    max_topic_id = second_topic.id
    later_topic = Fabricate(:topic)
    later_op = Fabricate(:post, topic: later_topic, post_number: 1)
    SiteSetting.nested_replies_backfill_batch_size = 1

    described_class.new.execute(after_topic_id:, max_topic_id:)

    expect(NestedViewPostStat.exists?(post_id: first_op.id)).to eq(true)
    expect(NestedViewPostStat.exists?(post_id: second_op.id)).to eq(false)
    expect(described_class.jobs.size).to eq(1)
    expect(described_class.jobs.first["at"]).to be_nil
    continuation = described_class.jobs.first["args"].first.with_indifferent_access
    expect(continuation).to include(after_topic_id: first_topic.id, max_topic_id: max_topic_id)

    described_class.jobs.clear
    described_class.new.execute(continuation)

    expect(NestedViewPostStat.exists?(post_id: second_op.id)).to eq(true)
    expect(NestedViewPostStat.exists?(post_id: later_op.id)).to eq(false)
    expect(described_class.jobs).to be_empty
  end

  it "isolates a failed topic so later topics are still prepared" do
    after_topic_id = Topic.maximum(:id).to_i
    failed_topic = Fabricate(:topic)
    Fabricate(:post, topic: failed_topic, post_number: 1)
    healthy_topic = Fabricate(:topic)
    healthy_op = Fabricate(:post, topic: healthy_topic, post_number: 1)
    allow(Discourse).to receive(:warn_exception)
    allow(Jobs::BackfillNestedReplyStats).to receive(:backfill_topic).and_call_original
    allow(Jobs::BackfillNestedReplyStats).to receive(:backfill_topic).with(
      failed_topic.id,
    ).and_raise("boom")

    described_class.new.execute(after_topic_id:, max_topic_id: healthy_topic.id)

    expect(NestedViewPostStat.exists?(post_id: healthy_op.id)).to eq(true)
    expect(described_class.jobs.size).to eq(1)
    retry_args = described_class.jobs.first["args"].first.with_indifferent_access
    expect(retry_args).to include(topic_id: failed_topic.id)
    expect { described_class.new.execute(retry_args) }.to raise_error("boom")
  end
end
