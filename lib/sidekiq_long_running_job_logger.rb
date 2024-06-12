# frozen_string_literal: true

class SidekiqLongRunningJobLogger
  attr_reader :thread

  def initialize(stuck_sidekiq_job_minutes:)
    @mutex = Mutex.new
    @stop_requested = false

    # Assume that setting the value of `stuck_sidekiq_job_minutes` lower than 0 is a mistake and set it to 1. This makes
    # the code in this class easier to reason about.
    @stuck_sidekiq_job_minutes = stuck_sidekiq_job_minutes <= 0 ? 1 : stuck_sidekiq_job_minutes.ceil
  end

  def start
    @thread ||=
      begin
        hostname = Discourse.os_hostname
        seconds_to_sleep_between_checks = (@stuck_sidekiq_job_minutes * 60) / 2

        Thread.new do
          loop do
            break if self.stop_requested?

            begin
              current_long_running_jobs = Set.new

              Sidekiq::Workers.new.each do |process_id, thread_id, work|
                next unless process_id.start_with?(hostname)

                if Time.at(work["run_at"]).to_i >=
                     (Time.now - (60 * @stuck_sidekiq_job_minutes)).to_i
                  next
                end

                jid = work.dig("payload", "jid")
                current_long_running_jobs << jid

                next if @seen_long_running_jobs&.include?(jid)

                if thread = Thread.list.find { |t| t["sidekiq_tid"] == thread_id }
                  Rails.logger.warn(<<~MSG)
                Sidekiq job `#{work.dig("payload", "class")}` has been running for more than #{@stuck_sidekiq_job_minutes} minutes
                #{thread.backtrace.join("\n")}
                MSG
                end
              end

              @seen_long_running_jobs = current_long_running_jobs

              yield if block_given?
            rescue => error
              Discourse.warn_exception(
                error,
                message: "Unexpected error in SidekiqLongRunningJobChecker thread",
              )
            end

            sleep seconds_to_sleep_between_checks
          end
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
