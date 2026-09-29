# frozen_string_literal: true

RSpec.describe BrowserPageviewSessionRollupSummary do
  self.use_transactional_tests = false

  describe ".refresh_recent!" do
    it "does not lose a concurrent pageview write while acknowledging an earlier generation" do
      date = 1.day.ago.to_date
      event = Fabricate(:browser_pageview_event, created_at: date.to_time(:utc) + 8.hours)
      session_id = event.session_id
      described_class.refresh_recent!(start_date: date, end_date: Time.zone.today)
      Fabricate(:browser_pageview_event, session_id:, created_at: date.to_time(:utc) + 9.hours)
      locked = Queue.new
      release = Queue.new
      writer_started = Queue.new
      pause_first_refresh = true
      allow(described_class).to receive(:replace_summaries!).and_wrap_original do |method, **args|
        if pause_first_refresh
          pause_first_refresh = false
          locked << true
          release.pop
        end
        method.call(**args)
      end
      connection_options =
        ActiveRecord::Base.connection.raw_connection.conninfo_hash.reject do |_, value|
          value.blank?
        end
      ActiveRecord::Base.connection_pool.release_connection

      refresher =
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            described_class.refresh_recent!(start_date: date, end_date: Time.zone.today)
          end
        end
      Timeout.timeout(5) { locked.pop }
      writer =
        Thread.new do
          PG.connect(connection_options) do |connection|
            writer_started << true
            connection.exec_params(
              "INSERT INTO browser_pageview_events (url, ip_address, user_agent, session_id, created_at) VALUES ($1, $2, $3, $4, $5)",
              ["/", "127.0.0.1", "spec", session_id, date.to_time(:utc) + 10.hours],
            )
          end
        end
      Timeout.timeout(5) { writer_started.pop }
      sleep 0.05
      expect(writer).to be_alive

      release << true
      refresher.value
      writer.value

      summary = described_class.find(session_id)
      expect(
        summary.pageview_count == 3 || summary.dirty_generation > summary.refreshed_generation,
      ).to eq(true)
      described_class.refresh_recent!(start_date: date, end_date: Time.zone.today)
      expect(described_class.find(session_id).pageview_count).to eq(3)
    ensure
      release << true if release && release.empty?
      refresher&.join(5)
      writer&.join(5)
      if session_id
        BrowserPageviewEvent.where(session_id:).delete_all
        described_class.where(session_id:).delete_all
        BrowserPageviewSessionEngagementDailyRollup.where(date:).delete_all
        ActiveRecord::Base.connection.execute(
          "DELETE FROM browser_pageview_session_rollup_repair_dates",
        )
        ActiveRecord::Base.connection.execute(
          "DELETE FROM browser_pageview_session_rollup_statuses",
        )
      end
    end
  end
end
