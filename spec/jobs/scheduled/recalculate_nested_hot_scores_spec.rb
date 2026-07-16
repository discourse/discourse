# frozen_string_literal: true

RSpec.describe Jobs::RecalculateNestedHotScores do
  before do
    SiteSetting.nested_replies_enabled = true
    SiteSetting.nested_replies_hot_sort_enabled = true
    NestedReplies::HotScoreQueue.clear
  end

  after { NestedReplies::HotScoreQueue.clear }

  def build_eligible_topic
    topic = Fabricate(:topic)
    op = Fabricate(:post, topic: topic, post_number: 1)
    Fabricate(:nested_topic, topic: topic)
    replies = 5.times.map { Fabricate(:post, topic: topic, reply_to_post_number: op.post_number) }
    topic.update_columns(posts_count: 6)
    [topic, replies]
  end

  def snapshot_topic_ids
    DB.query_single("SELECT topic_id FROM nested_hot_score_snapshots ORDER BY topic_id")
  end

  it "leaves queued demand untouched while the default-off gate is disabled" do
    topic, = build_eligible_topic
    NestedReplies::HotScoreQueue.enqueue(topic.id)
    SiteSetting.nested_replies_hot_sort_enabled = false

    described_class.new.execute

    expect(snapshot_topic_ids).to be_empty
    expect(NestedReplies::HotScoreQueue.pop).to eq(topic.id)
  end

  it "rebuilds only requested topics regardless of their declared size" do
    requested_topic, = build_eligible_topic
    unrequested_topic, = build_eligible_topic
    requested_topic.update_columns(posts_count: 1_000_000)
    NestedReplies::HotScoreQueue.enqueue(requested_topic.id)

    events =
      DiscourseEvent.track_events(:nested_replies_hot_scores_processed) do
        described_class.new.execute
      end

    expect(snapshot_topic_ids).to eq([requested_topic.id])
    expect(snapshot_topic_ids).not_to include(unrequested_topic.id)
    expect(events.dig(0, :params, 0)).to include(
      topics_inspected: 1,
      topics_rebuilt: 1,
      posts_rebuilt: 5,
      failures: 0,
      cooldowns_started: 0,
      queue_depth: 0,
    )
  end

  it "limits the number of queued topics inspected per run" do
    SiteSetting.nested_replies_hot_max_topics_per_run = 1
    first_topic, = build_eligible_topic
    second_topic, = build_eligible_topic
    NestedReplies::HotScoreQueue.enqueue(first_topic.id)
    NestedReplies::HotScoreQueue.enqueue(second_topic.id)

    described_class.new.execute

    expect(snapshot_topic_ids).to eq([first_topic.id])
    expect(NestedReplies::HotScoreQueue.pop).to eq(second_topic.id)
  end

  it "puts a malformed topic into cooldown instead of retrying every request" do
    SiteSetting.nested_replies_hot_failure_cooldown_minutes = 120
    topic, replies = build_eligible_topic
    replies.first.update_columns(reply_to_post_number: replies.second.post_number)
    replies.second.update_columns(reply_to_post_number: replies.first.post_number)
    NestedReplies::HotScoreQueue.enqueue(topic.id)
    allow(Discourse).to receive(:warn_exception)

    described_class.new.execute

    expect(snapshot_topic_ids).to be_empty
    expect(NestedReplies::HotScoreQueue.enqueue(topic.id)).to eq(:cooldown)
    expect(NestedReplies::HotScoreQueue.enqueue(topic.id, requested_at: 61.minutes.from_now)).to eq(
      :cooldown,
    )
    expect(
      NestedReplies::HotScoreQueue.enqueue(topic.id, requested_at: 121.minutes.from_now),
    ).to eq(:queued)
    expect(Discourse).to have_received(:warn_exception) do |error, message:|
      expect(error).to be_a(NestedReplies::HotScoreCalculator::InvalidTree)
      expect(message).to eq("Failed to refresh nested hot scores for topic #{topic.id}")
    end
  end
end
