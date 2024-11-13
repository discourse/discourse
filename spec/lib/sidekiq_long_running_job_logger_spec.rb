# frozen_string_literal: true

require "sidekiq_long_running_job_logger"

RSpec.describe SidekiqLongRunningJobLogger do
  let(:fake_logger) { FakeLogger.new }

  before { Rails.logger.broadcast_to(fake_logger) }

  after { Rails.logger.stop_broadcasting_to(fake_logger) }

  it "logs long-running jobs" do
    hostname = Discourse.os_hostname
    stuck_sidekiq_job_minutes = 10

    Sidekiq::Workers
      .expects(:new)
      .returns(
        [
          [
            "#{hostname}:1234",
            "some_sidekiq_id",
            {
              "run_at" => (Time.now - (60 * (stuck_sidekiq_job_minutes + 1))).to_i,
              "payload" => {
                "jid" => "job_1",
                "class" => "TestWorker",
              },
            },
          ],
          [
            "#{hostname}:1234",
            "some_other_sidekiq_id",
            {
              "run_at" => Time.now.to_i,
              "payload" => {
                "jid" => "job_2",
                "class" => "AnotherWorker",
              },
            },
          ],
        ],
      )
      .twice

    thread = mock("Thread")
    thread.expects(:[]).with("sidekiq_tid").returns("some_sidekiq_id").once
    thread.expects(:backtrace).returns(%w[line lines]).once
    Thread.expects(:list).returns([thread]).once

    begin
      checker = described_class.new(stuck_sidekiq_job_minutes:)

      loops = 0

      checker.start { loops += 1 }

      wait_for { loops == 1 }

      expect(fake_logger.warnings.size).to eq(1)

      expect(fake_logger.warnings).to include(
        "Sidekiq job `TestWorker` has been running for more than 10 minutes\nline\nlines\n",
      )

      checker.thread.wakeup # Force the thread to run the next loop

      wait_for { loops == 2 }

      expect(fake_logger.warnings.size).to eq(1)

      expect(fake_logger.warnings).to include(
        "Sidekiq job `TestWorker` has been running for more than 10 minutes\nline\nlines\n",
      )
    ensure
      checker.stop
    end
  end
end
