# frozen_string_literal: true

RSpec.describe Jobs::TopicTimerEnqueuer do
  subject(:job) { described_class.new }

  fab!(:timer1) do
    Fabricate(
      :topic_timer,
      execute_at: 1.minute.ago,
      created_at: 1.hour.ago,
      status_type: TopicTimer.types[:close],
    )
  end
  fab!(:timer2) do
    Fabricate(
      :topic_timer,
      execute_at: 1.minute.ago,
      created_at: 1.hour.ago,
      status_type: TopicTimer.types[:open],
    )
  end
  fab!(:future_timer) do
    Fabricate(
      :topic_timer,
      execute_at: 1.hour.from_now,
      created_at: 1.hour.ago,
      status_type: TopicTimer.types[:close],
    )
  end
  fab!(:deleted_timer) do
    Fabricate(
      :topic_timer,
      execute_at: 1.minute.ago,
      created_at: 1.hour.ago,
      status_type: TopicTimer.types[:close],
    )
  end

  before { deleted_timer.trash! }

  it "does not enqueue deleted timers" do
    expect_not_enqueued_with(job: :close_topic, args: { topic_timer_id: deleted_timer.id })
    job.execute
    expect(deleted_timer.topic.reload.closed?).to eq(false)
  end

  it "does not enqueue future timers" do
    expect_not_enqueued_with(job: :close_topic, args: { topic_timer_id: future_timer.id })
    job.execute
    expect(future_timer.topic.reload.closed?).to eq(false)
  end

  it "enqueues the related job" do
    expect_not_enqueued_with(job: :close_topic, args: { topic_timer_id: deleted_timer.id })
    expect_not_enqueued_with(job: :close_topic, args: { topic_timer_id: future_timer.id })
    job.execute
    expect_job_enqueued(job: :close_topic, args: { topic_timer_id: timer1.id })
    expect_job_enqueued(job: :open_topic, args: { topic_timer_id: timer2.id })
  end

  it "does not re-enqueue a job that has already been scheduled ahead of time in sidekiq (legacy topic timers)" do
    expect_not_enqueued_with(job: :close_topic, args: { topic_timer_id: timer1.id })
    Jobs.enqueue_at(1.hour.from_now, :close_topic, topic_timer_id: timer1.id)
    job.execute
  end

  it "skips obsolete reminder timers without warnings while enqueueing supported timers" do
    [nil, 1.day.ago].each do |deleted_at|
      Fabricate(
        :topic_timer,
        topic: Fabricate(:topic, deleted_at: deleted_at),
        execute_at: 1.minute.ago,
        created_at: 1.hour.ago,
        status_type: TopicTimer.types[:reminder],
      )
    end
    slow_mode_timer =
      Fabricate(
        :topic_timer,
        execute_at: 1.minute.ago,
        created_at: 1.hour.ago,
        status_type: TopicTimer.types[:clear_slow_mode],
      )

    logger = track_log_messages { job.execute }

    expect(logger.warnings).to be_empty
    expect_job_enqueued(job: :close_topic, args: { topic_timer_id: timer1.id })
    expect_job_enqueued(job: :open_topic, args: { topic_timer_id: timer2.id })
    expect_job_enqueued(job: :clear_slow_mode, args: { topic_timer_id: slow_mode_timer.id })
  end

  it "does not fail to enqueue other timers just because one timer errors" do
    TopicTimer.any_instance.stubs(:enqueue_typed_job).raises(StandardError).then.returns(true)
    expect { job.execute }.not_to raise_error
  end
end
