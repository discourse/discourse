# frozen_string_literal: true

RSpec.describe Demon::Sidekiq do
  describe ".heartbeat_check" do
    let(:daemon) { described_class.new(0, rails_root: @rails_root) }
    let(:original_pid) { 123_456 }
    let(:replacement_pid) { 123_457 }

    around do |example|
      Dir.mktmpdir do |directory|
        @rails_root = Pathname.new(directory)
        example.run
      end
    end

    before do
      Discourse.stubs(:before_fork)
      Sidekiq::ProcessSet.stubs(:new).returns([])
      Process.stubs(:clock_gettime).with(Process::CLOCK_MONOTONIC).returns(0)
      Process.stubs(:kill).with(0, original_pid).returns(1)
      daemon.stubs(:fork).returns(original_pid, replacement_pid)
      described_class.set_demons({ "sidekiq_0" => daemon })
    end

    after { described_class.reset_demons }

    it "allows an unregistered worker to start until the startup grace period expires" do
      daemon.start
      described_class.heartbeat_check
      expect(daemon.pid).to eq(original_pid)

      Process
        .stubs(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC)
        .returns(described_class::SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS - 1)
      described_class.heartbeat_check
      expect(daemon.pid).to eq(original_pid)

      Process
        .stubs(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC)
        .returns(described_class::SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS)
      Process.stubs(:kill).with(0, original_pid).returns(1).then.raises(Errno::ESRCH)
      Process.expects(:kill).with("TERM", original_pid)
      Process.stubs(:waitpid).with(original_pid, Process::WNOHANG).returns(original_pid)

      described_class.heartbeat_check

      expect(daemon.pid).to eq(replacement_pid)
    end

    it "renews the startup grace period when replacing a dead worker" do
      daemon.start
      Process
        .stubs(:clock_gettime)
        .with(Process::CLOCK_MONOTONIC)
        .returns(described_class::SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS + 1)
      Process.stubs(:waitpid).with(original_pid, Process::WNOHANG).returns(original_pid)
      Process.stubs(:kill).with(0, original_pid).raises(Errno::ESRCH)
      Process.stubs(:kill).with(0, replacement_pid).returns(1)
      Process.expects(:kill).with("TERM", replacement_pid).never

      described_class.ensure_running
      described_class.heartbeat_check

      expect(daemon.pid).to eq(replacement_pid)
    end

    it "restarts a registered worker with a stale heartbeat during the startup grace period" do
      daemon.start
      Sidekiq::ProcessSet.stubs(:new).returns(
        [
          {
            "hostname" => described_class::HOSTNAME,
            "pid" => original_pid,
            "beat" =>
              Time.now.to_i - described_class::SIDEKIQ_HEARTBEAT_CHECK_MISS_THRESHOLD_SECONDS - 1,
          },
        ],
      )
      Process.stubs(:kill).with(0, original_pid).returns(1).then.raises(Errno::ESRCH)
      Process.expects(:kill).with("TERM", original_pid)
      Process.stubs(:waitpid).with(original_pid, Process::WNOHANG).returns(original_pid)

      described_class.heartbeat_check

      expect(daemon.pid).to eq(replacement_pid)
    end

    it "restarts Sidekiq daemons missing from Sidekiq::ProcessSet or with a missed heartbeat" do
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
    it "restarts Sidekiq daemons whose RSS memory exceeds the allowed maximum" do
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
