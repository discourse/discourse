# frozen_string_literal: true

require "mini_scheduler_long_running_job_logger"

RSpec.describe MiniSchedulerLongRunningJobLogger do
  class Every10MinutesJob
    extend ::MiniScheduler::Schedule

    every 10.minutes

    def perform
      sleep 10_000
    end
  end

  class DailyJob
    extend ::MiniScheduler::Schedule

    daily at: 4.hours

    def perform
      sleep 10_000
    end
  end

  def with_running_scheduled_job(job_class)
    manager = MiniScheduler::Manager.new(enable_stats: false)

    info = manager.schedule_info(job_class)
    info.next_run = Time.now.to_i - 1
    info.write!
    manager.tick

    wait_for { manager.schedule_info(job_class).prev_result == "RUNNING" }

    yield
  ensure
    manager.stop!
  end

  before do
    @orig_logger = Rails.logger
    Rails.logger = @fake_logger = FakeLogger.new
  end

  after { Rails.logger = @orig_logger }

  it "logs long running jobs" do
    with_running_scheduled_job(Every10MinutesJob) do
      freeze_time(31.minutes.from_now)

      begin
        checker = described_class.new

        loops = 0

        checker.start { loops += 1 }

        wait_for { loops == 1 }

        expect(@fake_logger.warnings.size).to eq(1)

        expect(@fake_logger.warnings.first).to match(
          "Sidekiq scheduled job `Every10MinutesJob` has been running for more than 30 minutes",
        )

        # Matches the backtrace
        expect(@fake_logger.warnings.first).to match("sleep")

        # Check that the logger doesn't log repeated warnings after 2 loops
        expect do
          checker.thread.wakeup # Force the thread to run the next loop

          wait_for { loops == 2 }
        end.not_to change { @fake_logger.warnings.size }

        # Check that the logger doesn't log repeated warnings after 3 loops
        expect do
          checker.thread.wakeup # Force the thread to run the next loop

          wait_for { loops == 3 }
        end.not_to change { @fake_logger.warnings.size }
      ensure
        checker.stop
        expect(checker.thread).to eq(nil)
      end
    end
  end

  it "logs long running jobs with daily schedule" do
    with_running_scheduled_job(DailyJob) do
      freeze_time(3.hours.from_now)

      begin
        checker = described_class.new

        loops = 0

        checker.start { loops += 1 }

        wait_for { loops == 1 }

        expect(@fake_logger.warnings.size).to eq(1)

        expect(@fake_logger.warnings.first).to match(
          "Sidekiq scheduled job `DailyJob` has been running for more than 120 minutes",
        )
      ensure
        checker.stop
        expect(checker.thread).to eq(nil)
      end
    end
  end
end
