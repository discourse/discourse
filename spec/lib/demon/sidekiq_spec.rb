# frozen_string_literal: true

RSpec.describe Demon::Sidekiq do
  describe ".heartbeat_check" do
    it "should restart sidekiq daemons when daemon cannot be match to an entry in Sidekiq::ProcessSet or when heartbeat check has been missed" do
      running_sidekiq_daemon = described_class.new(1)
      running_sidekiq_daemon.set_pid(1)
      missing_sidekiq_daemon = described_class.new(2)
      missing_sidekiq_daemon.set_pid(2)
      missed_heartbeat_sidekiq_daemon = described_class.new(3)
      missed_heartbeat_sidekiq_daemon.set_pid(3)

      Sidekiq::ProcessSet.expects(:new).returns(
        [
          { "hostname" => described_class::HOSTNAME, "pid" => 1, "beat" => Time.now.to_i },
          {
            "hostname" => described_class::HOSTNAME,
            "pid" => 3,
            "beat" =>
              Time.now.to_i - described_class::SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS - 1,
          },
        ],
      )

      described_class.set_demons(
        {
          "running_sidekiq_daemon" => running_sidekiq_daemon,
          "missing_sidekiq_daemon" => missing_sidekiq_daemon,
          "missed_heartbeat_sidekiq_daemon" => missed_heartbeat_sidekiq_daemon,
        },
      )

      running_sidekiq_daemon.expects(:already_running?).returns(true)
      missing_sidekiq_daemon.expects(:already_running?).returns(true)
      missed_heartbeat_sidekiq_daemon.expects(:already_running?).returns(true)

      running_sidekiq_daemon.expects(:restart).never
      missing_sidekiq_daemon.expects(:restart)
      missed_heartbeat_sidekiq_daemon.expects(:restart)

      described_class.heartbeat_check
    ensure
      described_class.reset_demons
    end
  end

  describe ".rss_memory_check" do
    it "should restart sidekiq daemons when daemon's RSS memory exceeds the maximum allowed RSS memory" do
      stub_const(described_class, "SIDEKIQ_RSS_MEMORY_CHECK_INTERVAL_SECONDS", 0) do
        # Set to a negative value to fake that the process has exceeded the maximum allowed RSS memory
        stub_const(described_class, "DEFAULT_MAX_ALLOWED_SIDEKIQ_RSS_MEGABYTES", -1) do
          sidekiq_daemon = described_class.new(1)
          sidekiq_daemon.set_pid(1)

          described_class.set_demons({ "sidekiq_daemon" => sidekiq_daemon })

          sidekiq_daemon.expects(:already_running?).returns(true)
          sidekiq_daemon.expects(:restart)

          described_class.rss_memory_check
        end
      end
    ensure
      described_class.reset_demons
    end
  end
end
