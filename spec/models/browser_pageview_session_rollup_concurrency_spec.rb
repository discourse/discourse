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
      refresher_started = Queue.new
      writer_started = Queue.new
      connection_options =
        ActiveRecord::Base.connection.raw_connection.conninfo_hash.reject do |_, value|
          value.blank?
        end
      ActiveRecord::Base.connection_pool.release_connection
      blocker = PG.connect(connection_options)
      blocker.exec("BEGIN")
      blocker_open_transaction = true
      blocker.exec("LOCK TABLE browser_pageview_session_engagements IN ACCESS EXCLUSIVE MODE")
      blocker_pid = blocker.exec("SELECT pg_backend_pid()").getvalue(0, 0).to_i

      refresher =
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            refresher_started << ActiveRecord::Base.connection.select_value(
              "SELECT pg_backend_pid()",
            )
            described_class.refresh_recent!(start_date: date, end_date: Time.zone.today)
          end
        end
      refresher_pid = Timeout.timeout(5) { refresher_started.pop }
      wait_until_blocked_by(refresher_pid, blocker_pid)
      writer =
        Thread.new do
          PG.connect(connection_options) do |connection|
            writer_started << connection.exec("SELECT pg_backend_pid()").getvalue(0, 0).to_i
            connection.exec_params(
              "INSERT INTO browser_pageview_events (url, ip_address, user_agent, session_id, created_at) VALUES ($1, $2, $3, $4, $5)",
              ["/", "127.0.0.1", "spec", session_id, date.to_time(:utc) + 10.hours],
            )
          end
        end
      writer_pid = Timeout.timeout(5) { writer_started.pop }
      wait_until_blocked_by(writer_pid, refresher_pid)

      blocker.exec("COMMIT")
      blocker_open_transaction = false
      refresher.value
      writer.value

      summary = described_class.find(session_id)
      expect(
        summary.pageview_count == 3 || summary.dirty_generation > summary.refreshed_generation,
      ).to eq(true)
      described_class.refresh_recent!(start_date: date, end_date: Time.zone.today)
      expect(described_class.find(session_id).pageview_count).to eq(3)
    ensure
      blocker&.exec("ROLLBACK") if blocker_open_transaction
      blocker&.close
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

  def wait_until_blocked_by(waiter_pid, blocker_pid)
    Timeout.timeout(5) do
      loop do
        blocked =
          ActiveRecord::Base.connection.select_value(
            "SELECT #{Integer(blocker_pid)} = ANY(pg_blocking_pids(#{Integer(waiter_pid)}))",
          )
        break if blocked

        sleep 0.01
      end
    end
  end
end
