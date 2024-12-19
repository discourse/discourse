# frozen_string_literal: true

RSpec.describe Demon::EmailSync do
  describe ".check_email_sync_heartbeat" do
    after do
      described_class.reset_demons
      described_class.test_cleanup
    end

    it "should restart email sync daemons when last heartbeat is older than the heartbeat interval" do
      track_log_messages do |logger|
        daemon = described_class.new(1)
        daemon.set_pid(999_999)

        described_class.set_demons({ "daemon" => daemon })

        Discourse.redis.set(
          described_class::HEARTBEAT_KEY,
          Time.now.to_i - described_class::HEARTBEAT_INTERVAL.to_i - 1,
        )

        daemon.expects(:restart)

        described_class.check_email_sync_heartbeat

        expect(logger.warnings.first).to eq(
          "EmailSync heartbeat test failed (last heartbeat was 61s ago), restarting",
        )
      end
    end

    it "should restart email sync daemons when memory usage exceeds the maximum allowed memory" do
      track_log_messages do |logger|
        daemon = described_class.new(1)
        daemon.set_pid(999_999)

        described_class.set_demons({ "daemon" => daemon })

        Discourse.redis.set(described_class::HEARTBEAT_KEY, Time.now.to_i)

        daemon.expects(:restart)

        # Set to negative value to fake that process is using too much memory
        described_class.expects(:max_allowed_email_sync_rss).returns(-1)
        described_class.check_email_sync_heartbeat

        expect(logger.warnings.first).to eq(
          "EmailSync is consuming too much memory (using: 0.00M) for '#{described_class::HOSTNAME}', restarting",
        )
      end
    end
  end
end
