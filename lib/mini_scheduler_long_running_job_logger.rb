# frozen_string_literal: true

class MiniSchedulerLongRunningJobLogger
  DEFAULT_POLL_INTERVAL_SECONDS = 6

  attr_reader :thread

  def initialize(poll_interval_seconds: nil)
    @mutex = Mutex.new
    @stop_requested = false

    @poll_interval_seconds =
      if poll_interval_seconds
        begin
          Integer(poll_interval_seconds)
        rescue ArgumentError
          DEFAULT_POLL_INTERVAL_SECONDS
        end
      else
        DEFAULT_POLL_INTERVAL_SECONDS
      end
  end

  def start
    @thread ||=
      Thread.new do
        hostname = Discourse.os_hostname

        loop do
          break if self.stop_requested?

          current_long_running_jobs = Set.new

          begin
            MiniScheduler::Manager.discover_running_scheduled_jobs.each do |job|
              job_class = job[:class]
              job_started_at = job[:started_at]
              mini_scheduler_worker_thread_id = job[:thread_id]

              job_frequency_minutes =
                if job_class.daily
                  1.day.in_minutes.minutes
                else
                  job_class.every.in_minutes.minutes
                end

              warning_duration =
                begin
                  if job_frequency_minutes < 30.minutes
                    30.minutes
                  elsif job_frequency_minutes < 2.hours
                    job_frequency_minutes
                  else
                    2.hours
                  end
                end

              next if job_started_at >= (Time.zone.now - warning_duration)

              running_thread =
                Thread.list.find do |thread|
                  thread[:mini_scheduler_worker_thread_id] == mini_scheduler_worker_thread_id
                end

              next if running_thread.nil?

              current_long_running_jobs << job_class

              next if @seen_long_running_jobs&.include?(job_class)

              Rails.logger.warn(<<~MSG)
                  Sidekiq scheduled job `#{job_class}` has been running for more than #{warning_duration.in_minutes.to_i} minutes
                  #{running_thread.backtrace.join("\n")}
                  MSG
            end

            @seen_long_running_jobs = current_long_running_jobs

            yield if block_given?
          rescue => error
            Discourse.warn_exception(
              error,
              message: "Unexpected error in MiniSchedulerLongRunningJobLogger thread",
            )
          end

          sleep @poll_interval_seconds
        end
      end
  end

  # Used for testing to stop the thread. In production, the thread is expected to live for the lifetime of the process.
  def stop
    @mutex.synchronize { @stop_requested = true }

    if @thread
      @thread.wakeup
      @thread.join
      @thread = nil
    end
  end

  private

  def stop_requested?
    @mutex.synchronize { @stop_requested }
  end
end
