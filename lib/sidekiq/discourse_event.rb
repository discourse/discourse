# frozen_string_literal: true

class Sidekiq::DiscourseEvent
  def call(worker, msg, queue)
    start_time = clock_gettime
    result = yield
    trigger_discourse_event(event_name: :sidekiq_job_ran, worker:, msg:, queue:, start_time:)
    result
  rescue => error
    trigger_discourse_event(event_name: :sidekiq_job_error, worker:, msg:, queue:, start_time:)
    raise error
  end

  private

  def trigger_discourse_event(event_name:, worker:, msg:, queue:, start_time:)
    duration = clock_gettime - start_time
    DiscourseEvent.trigger(event_name, worker, msg, queue, duration)
  end

  def clock_gettime
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end
end
