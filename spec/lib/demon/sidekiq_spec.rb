# frozen_string_literal: true

require "sidekiq/cli"

RSpec.describe Demon::Sidekiq do
  describe "#run" do
    let(:rails_root) { Dir.mktmpdir }
    let(:demon) { described_class.new(1, rails_root: "#{rails_root}/", logger: Logger.new(nil)) }

    before do
      demon.stubs(:monitor_parent)
      demon.stubs(:establish_app)
    end

    after { FileUtils.rm_rf(rails_root) }

    it "starts the Sidekiq CLI with nice value 5" do
      reader, writer = IO.pipe
      cli = Object.new
      cli.define_singleton_method(:parse) do |_options|
        writer.write(Process.getpriority(Process::PRIO_PROCESS, Process.pid).to_s)
        writer.close
        exit!(0)
      end
      Sidekiq::CLI.stubs(:instance).returns(cli)

      demon.run
      writer.close
      status = Process.wait2(demon.pid).last

      expect(reader.read).to eq("5")
      expect(status).to be_success
    ensure
      reader&.close
      writer&.close unless writer&.closed?
    end

    it "exits when setting the process priority fails" do
      Process.stubs(:setpriority).raises(Errno::EACCES)

      demon.run
      status = Process.wait2(demon.pid).last

      expect(status.exitstatus).to eq(1)
    end
  end

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
