# frozen_string_literal: true

require "socket"

RSpec.describe AdminDashboardSiteTrafficDetail do
  describe AdminDashboardSiteTrafficDetail::DeadlineExecutor do
    class BarrierQuery
      def initialize(started)
        @started = started
      end

      def query_hash(sql, binds)
        @started << :query_started
        DB.query_hash(sql, binds)
      end
    end

    class RecordingPool
      attr_reader :checked_out, :checked_in, :connection

      def initialize(connection)
        @connection = connection
      end

      def with_connection
        @checked_out = true
        yield @connection
      ensure
        @checked_in = true
      end
    end

    class RecordingConnection
      attr_reader :events, :transaction_options, :rolled_back

      def initialize(events)
        @events = events
      end

      def transaction(**options)
        @transaction_options = options
        events << :transaction
        yield
      rescue ActiveRecord::Rollback
        @rolled_back = true
      end

      def execute(statement)
        events << statement
      end
    end

    class SequenceClock
      def initialize(values)
        @values = values
      end

      def clock_gettime(*)
        @values.shift
      end
    end

    class RecordingQuery
      def initialize(events, result: [{ "value" => 1 }], error: nil)
        @events = events
        @result = result
        @error = error
      end

      def query_hash(*)
        @events << :analytics
        raise @error if @error

        @result
      end
    end

    def recording_executor(clock_values, events: [], query: RecordingQuery.new(events))
      connection = RecordingConnection.new(events)
      pool = RecordingPool.new(connection)
      executor =
        described_class.new(
          deadline_seconds: 1,
          pool: pool,
          query: query,
          clock: SequenceClock.new(clock_values),
        )

      [executor, connection, events, pool]
    end

    def wait_for_advisory_lock(connection, lock_id, stop_signal)
      loop do
        begin
          stop_signal.pop(true)
          return false
        rescue ThreadError
          nil
        end

        acquired =
          connection.exec_params("SELECT pg_try_advisory_xact_lock($1)", [lock_id]).getvalue(0, 0)
        return true if acquired == "f"

        Thread.pass
      end
    end

    it "executes every statement on one rolled-back read-only transaction within a decreasing budget" do
      executor, connection, events, pool =
        recording_executor([0, 0.1, 0.2, 0.3, 0.4, 0.5, 0.6, 0.7])

      result = executor.execute("SELECT :value", value: 1)

      expect(result).to eq([{ "value" => 1 }])
      expect(connection.transaction_options).to eq(requires_new: true)
      expect(events).to eq(
        [
          :transaction,
          "SET TRANSACTION READ ONLY",
          "SET LOCAL statement_timeout = 700",
          :analytics,
        ],
      )
      expect(connection.rolled_back).to eq(true)
      expect(pool.checked_out).to eq(true)
      expect(pool.checked_in).to eq(true)
    end

    it "starts the deadline before connection checkout and times out before database work" do
      executor, connection, events, pool = recording_executor([0, 1])

      expect { executor.execute("SELECT 1") }.to raise_error(
        AdminDashboardSiteTrafficDetail::Timeout,
      )
      expect(events).to eq([:transaction])
      expect(connection.rolled_back).to eq(nil)
      expect(pool.checked_in).to eq(true)
    end

    it "applies a decreasing remaining timeout before every bounded query" do
      executor, connection, events, pool =
        recording_executor([0, 0, 0, 0.1, 0.1, 0.2, 0.2, 0.3, 0.4, 0.4, 0.5, 0.5, 0.6])

      result =
        executor.execute { |query| [query.call(sql: "SELECT 1"), query.call(sql: "SELECT 2")] }

      expect(result).to eq([[{ "value" => 1 }], [{ "value" => 1 }]])
      expect(events).to eq(
        [
          :transaction,
          "SET TRANSACTION READ ONLY",
          "SET LOCAL statement_timeout = 900",
          :analytics,
          "SET LOCAL statement_timeout = 600",
          :analytics,
        ],
      )
      expect(connection.rolled_back).to eq(true)
      expect(pool.checked_in).to eq(true)
    end

    it "raises Timeout after the read-only statement before setting the local timeout" do
      executor, connection, events, pool = recording_executor([0, 0, 1])

      expect { executor.execute("SELECT 1") }.to raise_error(
        AdminDashboardSiteTrafficDetail::Timeout,
      )
      expect(events).to eq([:transaction, "SET TRANSACTION READ ONLY"])
      expect(connection.rolled_back).to eq(nil)
      expect(pool.checked_in).to eq(true)
    end

    it "raises Timeout before analytics after configuring the local timeout" do
      executor, connection, events, pool = recording_executor([0, 0, 0, 0, 0, 0, 1])

      expect { executor.execute("SELECT 1") }.to raise_error(
        AdminDashboardSiteTrafficDetail::Timeout,
      )
      expect(events).to eq(
        [:transaction, "SET TRANSACTION READ ONLY", "SET LOCAL statement_timeout = 1000"],
      )
      expect(connection.rolled_back).to eq(nil)
      expect(pool.checked_in).to eq(true)
    end

    it "raises Timeout after analytics and returns no partial result" do
      executor, connection, events, pool = recording_executor([0, 0, 0, 0, 0, 0, 0, 1])

      expect { executor.execute("SELECT 1") }.to raise_error(
        AdminDashboardSiteTrafficDetail::Timeout,
      )
      expect(events).to eq(
        [
          :transaction,
          "SET TRANSACTION READ ONLY",
          "SET LOCAL statement_timeout = 1000",
          :analytics,
        ],
      )
      expect(connection.rolled_back).to eq(nil)
      expect(pool.checked_in).to eq(true)
    end

    it "maps connection checkout exhaustion to Timeout before analytics" do
      pool = stub
      pool.expects(:with_connection).raises(ActiveRecord::ConnectionTimeoutError)
      query = stub
      query.expects(:query_hash).never

      expect do
        described_class.new(
          deadline_seconds: 1,
          pool: pool,
          query: query,
          clock: SequenceClock.new([0]),
        ).execute("SELECT 1")
      end.to raise_error(AdminDashboardSiteTrafficDetail::Timeout)
    end

    it "maps raw and wrapped statement timeouts while propagating unrelated database errors" do
      [
        PG::QueryCanceled.new("canceling statement due to statement timeout"),
        ActiveRecord::StatementInvalid.new("canceling statement due to statement timeout"),
      ].each do |error|
        events = []
        executor, _connection, _events, pool =
          recording_executor(
            Array.new(7, 0),
            events: events,
            query: RecordingQuery.new(events, error: error),
          )

        expect { executor.execute("SELECT 1") }.to raise_error(
          AdminDashboardSiteTrafficDetail::Timeout,
        )
        expect(pool.checked_in).to eq(true)
      end

      events = []
      executor, _connection, _events, pool =
        recording_executor(
          Array.new(7, 0),
          events: events,
          query:
            RecordingQuery.new(
              events,
              error: ActiveRecord::StatementInvalid.new("database unavailable"),
            ),
        )

      expect { executor.execute("SELECT 1") }.to raise_error(
        ActiveRecord::StatementInvalid,
        "database unavailable",
      )
      expect(pool.checked_in).to eq(true)
    end

    it "uses the checked-out connection, rolls back local changes, and remains usable after success" do
      connection = ActiveRecord::Base.connection
      expected_backend_pid = connection.select_value("SELECT pg_backend_pid()").to_i
      original_timeout = connection.select_value("SHOW statement_timeout")
      original_transaction_depth = connection.open_transactions

      result = described_class.new.execute(<<~SQL)
        SELECT pg_backend_pid() AS backend_pid,
               current_setting('transaction_read_only') AS transaction_read_only,
               current_setting('statement_timeout') AS statement_timeout
      SQL

      expect(result.first).to include(
        "backend_pid" => expected_backend_pid,
        "transaction_read_only" => "on",
      )
      expect(result.first.fetch("statement_timeout")).to match(/\A\d+(?:ms|s)\z/)
      expect(connection.select_value("SHOW statement_timeout")).to eq(original_timeout)
      expect(connection.open_transactions).to eq(original_transaction_depth)
      expect(connection.select_value("SELECT 1")).to eq(1)
    end

    it "uses the same checked-out connection for metadata and analytics queries" do
      result =
        described_class.new.execute do |query|
          [
            query.call(sql: "SELECT pg_backend_pid() AS backend_pid"),
            query.call(sql: "SELECT pg_backend_pid() AS backend_pid"),
          ]
        end

      expect(result.map { |rows| rows.first.fetch("backend_pid") }.uniq.length).to eq(1)
    end

    it "enforces read-only execution and releases the connection after a database error" do
      connection = ActiveRecord::Base.connection
      original_title = SiteSetting.title
      original_transaction_depth = connection.open_transactions

      expect do
        described_class.new.execute(
          "UPDATE site_settings SET value = 'changed' WHERE name = 'title'",
        )
      end.to raise_error(PG::ReadOnlySqlTransaction, /read-only/)

      expect(SiteSetting.title).to eq(original_title)
      expect(connection.open_transactions).to eq(original_transaction_depth)
      expect(connection.select_value("SELECT 1")).to eq(1)
    end

    it "cancels an active analytics query on disconnect and leaves the connection usable" do
      skip "PG::CancelConnection is unavailable" if !defined?(PG::CancelConnection)

      client_io, client_peer = Socket.pair(:UNIX, :STREAM, 0)
      query_started = Queue.new
      disconnect_stop = Queue.new
      lock_id = SecureRandom.random_number(2**31)
      monitor_connection =
        PG.connect(ActiveRecord::Base.connection.raw_connection.conninfo_hash.compact)
      disconnect =
        Thread.new do
          if query_started.pop == :query_started &&
               wait_for_advisory_lock(monitor_connection, lock_id, disconnect_stop)
            client_peer.close
          end
        end
      connection = ActiveRecord::Base.connection
      original_transaction_depth = connection.open_transactions
      started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

      expect do
        described_class.new(client_io: client_io, query: BarrierQuery.new(query_started)).execute(
          "SELECT pg_advisory_xact_lock(:lock_id)::text AS barrier, pg_sleep(5)::text AS waited, 1 AS value",
          lock_id: lock_id,
        )
      end.to raise_error(AdminDashboardSiteTrafficDetail::Timeout)
      elapsed_seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at
      disconnect.value

      expect(elapsed_seconds).to be < 3
      expect(connection.open_transactions).to eq(original_transaction_depth)
      expect(connection.select_value("SELECT 1")).to eq(1)
    ensure
      disconnect_stop << true if disconnect_stop
      query_started << :stop if query_started
      disconnect&.join
      monitor_connection&.finish if monitor_connection && !monitor_connection.finished?
      client_peer&.close if client_peer && !client_peer.closed?
      client_io&.close if client_io && !client_io.closed?
    end

    it "stops watching after success so a later disconnect cannot cancel later work" do
      skip "PG::CancelConnection is unavailable" if !defined?(PG::CancelConnection)

      client_io, client_peer = Socket.pair(:UNIX, :STREAM, 0)

      result = described_class.new(client_io: client_io).execute("SELECT 1 AS value")
      client_peer.close
      later_result = described_class.new.execute("SELECT pg_sleep(0.2)::text AS waited, 2 AS value")

      expect(result).to eq([{ "value" => 1 }])
      expect(later_result).to eq([{ "waited" => "", "value" => 2 }])
      expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
    ensure
      client_peer&.close if client_peer && !client_peer.closed?
      client_io&.close if client_io && !client_io.closed?
    end
  end

  describe AdminDashboardSiteTrafficDetail::Request do
    describe ".parse" do
      it "accepts canonical closed-contract input" do
        request =
          described_class.parse(
            ActionController::Parameters.new(
              start_date: "2026-05-01",
              end_date: "2026-05-12",
              filters: {
                country: "US",
                asn: "AS64500",
                ip: "192.0.2.1",
              },
            ),
          )

        expect(request.filters).to eq("country" => "US", "asn" => "AS64500", "ip" => "192.0.2.1")
      end

      it "rejects unknown, nested, and noncanonical values" do
        invalid_requests = [
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { country: "us" } },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { ip: "192.0.2.0/24" } },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { url: "/admin/users" } },
          { start_date: "2026-5-1", end_date: "2026-05-12", filters: {} },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { country: ["US"] } },
          {
            start_date: "2026-05-01",
            end_date: "2026-05-12",
            filters: {
              url: "/<img src=x onerror=alert(1)>",
            },
          },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { url: "/../admin" } },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { url: "/safe%2fpath" } },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { url: "/new" } },
          {
            start_date: "2026-05-01",
            end_date: "2026-05-12",
            filters: {
              url: "/plugin/private-helper",
            },
          },
          { start_date: "2026-05-01", end_date: "2026-05-12", filters: { browser: "other" } },
        ]

        invalid_requests.each do |params|
          expect { described_class.parse(ActionController::Parameters.new(params)) }.to raise_error(
            AdminDashboardSiteTrafficDetail::InvalidRequest,
          )
        end
      end

      it "accepts only canonical AS numbers that fit the stored integer column" do
        valid_request = {
          start_date: "2026-05-01",
          end_date: "2026-05-12",
          filters: {
            asn: "AS2147483647",
          },
        }
        invalid_asns = %w[AS0 AS01 AS2147483648]

        request = described_class.parse(ActionController::Parameters.new(valid_request))

        expect(request.filters["asn"]).to eq("AS2147483647")
        invalid_asns.each do |asn|
          params = valid_request.deep_merge(filters: { asn: })
          expect { described_class.parse(ActionController::Parameters.new(params)) }.to raise_error(
            AdminDashboardSiteTrafficDetail::InvalidRequest,
          )
        end
      end

      it "reports nominal retention truncation only while cleanup is enabled" do
        request =
          described_class.parse(
            ActionController::Parameters.new(
              start_date: 365.days.ago.to_date.iso8601,
              end_date: Date.current.iso8601,
              filters: {
              },
            ),
          )

        SiteSetting.clean_up_browser_pageview_events = true
        cleanup_enabled_result = AdminDashboardSiteTrafficDetail.new(request: request).call
        SiteSetting.clean_up_browser_pageview_events = false
        cleanup_disabled_result = AdminDashboardSiteTrafficDetail.new(request: request).call

        expect(cleanup_enabled_result.dig(:analysis, :retention_truncated)).to eq(true)
        expect(cleanup_disabled_result.dig(:analysis, :retention_truncated)).to eq(false)
      end
    end
  end

  describe "#call" do
    it "returns filtered classifier totals while keeping capped metadata unfiltered" do
      Fabricate(
        :browser_pageview_event,
        country_code: "US",
        url: "/about?private=value",
        user_agent: "Mozilla Firefox",
        session_id: "firefox-session",
        created_at: Time.zone.local(2026, 6, 2),
      )
      Fabricate(
        :browser_pageview_event,
        country_code: "CA",
        user_agent: "Mozilla Chrome",
        session_id: "chrome-session",
        score: CrawlerScorer::BOT_SCORE_THRESHOLD,
        created_at: Time.zone.local(2026, 6, 3),
      )
      BrowserPageviewSessionEngagement.create!(session_id: "firefox-session", engaged_seconds: 0)
      BrowserPageviewSessionEngagement.create!(session_id: "chrome-session", engaged_seconds: 20)
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: "2026-06-01",
            end_date: "2026-06-12",
            filters: {
              browser: "firefox",
            },
          ),
        )

      counts = described_class.new(request: request).call
      unfiltered_request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: "2026-06-01",
            end_date: "2026-06-12",
            filters: {
            },
          ),
        )
      unfiltered_counts = described_class.new(request: unfiltered_request).call
      summary = counts.fetch(:summary)
      analysis = counts.fetch(:analysis)
      dimensions = counts.fetch(:dimensions)

      expect(summary).to include(
        pageviews: 1,
        anonymous_human_pageviews: 1,
        likely_crawler_pageviews: 0,
      )
      expect(analysis).to include(analyzed_event_count: 2)
      expect(counts[:series]).to eq(
        [
          {
            "date" => "2026-06-02",
            "pageviews" => 1,
            "logged_in_human_pageviews" => 0,
            "anonymous_human_pageviews" => 1,
            "likely_crawler_pageviews" => 0,
          },
        ],
      )
      expect(summary).to include(
        distinct_sessions: 2,
        bounce_rate: 50,
        average_session_duration_seconds: 10,
      )
      expect(
        summary.slice(:distinct_sessions, :bounce_rate, :average_session_duration_seconds),
      ).to eq(
        unfiltered_counts.fetch(:summary).slice(
          :distinct_sessions,
          :bounce_rate,
          :average_session_duration_seconds,
        ),
      )
      expect(unfiltered_counts.dig(:summary, :pageviews)).to eq(2)
      expect(dimensions[:top_urls]).to include(include(value: "/about", label: "/about"))
      expect(dimensions[:top_urls].to_json).not_to include("private=value")
      expect(dimensions[:browsers].map { |row| row[:value] }).to contain_exactly(
        "chrome",
        "firefox",
      )
      country_request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: "2026-06-01",
            end_date: "2026-06-12",
            filters: {
              country: "US",
            },
          ),
        )
      country_counts = described_class.new(request: country_request).call
      expect(country_counts[:summary]).to include(pageviews: 1)
      expect(
        country_counts.dig(:dimensions, :countries).map { |row| row[:value] },
      ).to contain_exactly("US", "CA")
    end

    fab!(:event) do
      Fabricate(
        :browser_pageview_event,
        url: "/about?private=value",
        country_code: "US",
        ip_address: "192.0.2.1",
        user_agent: "Mozilla Firefox",
        session_id: "safe-session",
        created_at: Time.zone.local(2026, 5, 2, 10),
      )
    end

    it "sanitizes URLs before returning dimension rows" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: "2026-05-01",
            end_date: "2026-05-12",
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :top_urls)).to include(
        include(value: "/about", label: "/about", pageviews: 1),
      )
      expect(result.to_json).not_to include("private=value")
    end

    it "keeps a safe path when only its discarded query contains percent encoding" do
      Fabricate(:browser_pageview_event, url: "/about?q=hello%20world", session_id: "query-path")
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :top_urls)).to include(
        include(value: "/about", filterable: true),
      )
    end

    it "canonicalizes an internal absolute browser URL without returning its origin or query" do
      Discourse.stubs(:base_url).returns("https://test.localhost")
      Discourse.stubs(:current_hostname).returns("test.localhost")
      Fabricate(
        :browser_pageview_event,
        url: "https://test.localhost/about?campaign=secret#fragment",
        session_id: "absolute-url",
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
              url: "/about",
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:summary, :pageviews)).to eq(1)
      expect(result.to_json).not_to include("test.localhost")
      expect(result.to_json).not_to include("campaign=secret")
    end

    it "joins distinct safe paths back to every pageview before per-event classification" do
      Discourse.stubs(:base_url).returns("https://test.localhost")
      Discourse.stubs(:current_hostname).returns("test.localhost")
      [
        ["/latest?campaign=first", "Mozilla Firefox", "first.example"],
        ["https://test.localhost/latest?campaign=second", "Mozilla Chrome", "second.example"],
      ].each_with_index do |(url, user_agent, source), index|
        Fabricate(
          :browser_pageview_event,
          url: url,
          user_agent: user_agent,
          session_id: "canonical-path-#{index}",
          normalized_referrer: "#{source}/landing",
          normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        )
      end
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :top_urls)).to include(include(value: "/latest", pageviews: 2))
      expect(result.dig(:dimensions, :browsers).map { |row| row[:value] }).to contain_exactly(
        "chrome",
        "firefox",
      )
      expect(
        result.dig(:dimensions, :traffic_sources).map { |row| row[:value] },
      ).to contain_exactly("first.example", "second.example")
    end

    it "accepts only trusted absolute origins and returns canonical paths" do
      Discourse.stubs(:base_url).returns("https://www.site.example/forum")
      Discourse.stubs(:base_path).returns("/forum")
      Discourse.stubs(:current_hostname).returns("WWW.Site.Example.")
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(
        %w[Alias.Example. münchen.de.],
      )
      cases = {
        "https://www.site.example/forum/about?secret=value#fragment" => "/about",
        "https://www.site.example/forum?secret=value" => "/",
        "https://alias.example/forum/search" => "/search",
        "https://xn--mnchen-3ya.de/forum/privacy" => "/privacy",
        "/categories" => "/categories",
        "https://site.example/forum/secret" => nil,
        "https://evil.example/forum/secret" => nil,
        "https://www.site.example.evil/forum/secret" => nil,
        "https://user@www.site.example/forum/secret" => nil,
        "http://www.site.example/forum/secret" => nil,
        "https://www.site.example:444/forum/secret" => nil,
        "//www.site.example/forum/secret" => nil,
        "https://www.site.example/forumish/secret" => nil,
        "https://www.site.example/forum/\nsecret" => nil,
      }
      cases.each_with_index do |(url, expected_path), index|
        Fabricate(:browser_pageview_event, url: url, session_id: "absolute-#{index}")
      end
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call
      rows = result.dig(:dimensions, :top_urls)
      filterable_rows = rows.select { |row| row[:filterable] }
      redacted_row = rows.find { |row| !row[:filterable] }

      expect(filterable_rows.map { |row| row[:value] }).to contain_exactly(*cases.values.compact)
      expect(redacted_row).to include(
        value: nil,
        label: "Private or sensitive page",
        pageviews: cases.values.count(nil),
      )
      expect(result.to_json).not_to include(
        "secret=value",
        "www.site.example.evil",
        "user@",
        "www.site.example:444",
        "//www.site.example",
        "\nsecret",
      )
    end

    it "keeps replacement URL facets available while the summary remains URL-filtered" do
      Fabricate(:browser_pageview_event, url: "/about", country_code: "US", session_id: "first")
      Fabricate(:browser_pageview_event, url: "/search", country_code: "US", session_id: "second")
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
              url: "/about",
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:summary, :pageviews)).to eq(1)
      expect(result.dig(:dimensions, :top_urls).map { |row| row[:value] }).to contain_exactly(
        "/about",
        "/search",
      )
    end

    it "keeps zero-count replacements available for every filterable dimension" do
      Fabricate(
        :browser_pageview_event,
        url: "/top",
        country_code: "US",
        asn: 64_500,
        ip_address: "192.0.2.1",
        user_agent: "Mozilla Chrome",
        session_id: "matching",
      )
      Fabricate(
        :browser_pageview_event,
        url: "/about",
        country_code: "CA",
        asn: 64_501,
        ip_address: "198.51.100.2",
        user_agent: "Mozilla Firefox",
        session_id: "replacement",
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
              url: "/top",
              country: "US",
              asn: "AS64500",
              browser: "chrome",
              ip: "192.0.2.1",
            },
          ),
        )

      DiscourseIpInfo
        .stubs(:asn_organization)
        .with(ip: "192.0.2.1", expected_asn: 64_500)
        .returns("Example Network")
      DiscourseIpInfo
        .stubs(:asn_organization)
        .with(ip: "198.51.100.2", expected_asn: 64_501)
        .returns("Replacement Network")

      result = described_class.new(request: request).call

      expect(result.dig(:summary, :pageviews)).to eq(1)
      expect(result.dig(:dimensions, :top_urls)).to eq(
        [
          { value: "/top", label: "/top", pageviews: 1, filterable: true },
          { value: "/about", label: "/about", pageviews: 0, filterable: true },
        ],
      )
      expect(result.dig(:dimensions, :countries)).to eq(
        [
          { value: "US", label: "US", pageviews: 1, filterable: true },
          { value: "CA", label: "CA", pageviews: 0, filterable: true },
        ],
      )
      expect(result.dig(:dimensions, :networks)).to eq(
        [
          { value: "AS64500", label: "AS64500 Example Network", pageviews: 1, filterable: true },
          {
            value: "AS64501",
            label: "AS64501 Replacement Network",
            pageviews: 0,
            filterable: true,
          },
        ],
      )
      expect(result.dig(:dimensions, :browsers)).to eq(
        [
          { value: "chrome", label: "chrome", pageviews: 1, filterable: true },
          { value: "firefox", label: "firefox", pageviews: 0, filterable: true },
        ],
      )
      expect(result.dig(:dimensions, :ip_addresses)).to eq(
        [
          { value: "192.0.2.1", label: "192.0.2.1", pageviews: 1, filterable: true },
          { value: "198.51.100.2", label: "198.51.100.2", pageviews: 0, filterable: true },
        ],
      )
    end

    it "returns the first 50 dimension values in deterministic count and label order" do
      ip_addresses = (1..51).map { |index| "198.51.100.#{index}" }
      ip_addresses.each_with_index do |ip_address, index|
        Fabricate(
          :browser_pageview_event,
          ip_address: ip_address,
          session_id: "dimension-cap-#{index}",
        )
      end
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :ip_addresses).map { |row| row[:value] }).to eq(
        ip_addresses.sort.take(50),
      )
    end

    it "redacts a private-message route even when the event topic id names a public topic" do
      private_message = Fabricate(:private_message_topic)
      public_topic = Fabricate(:topic)
      Fabricate(
        :browser_pageview_event,
        url: "/t/#{private_message.slug}/#{private_message.id}",
        topic_id: public_topic.id,
        session_id: "private-route",
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :top_urls)).to include(
        include(value: nil, label: "Private or sensitive page", filterable: false),
      )
      expect(result.to_json).not_to include(private_message.slug)
    end

    it "redacts a regular topic route in a read-restricted category" do
      restricted_category = Fabricate(:category, read_restricted: true)
      restricted_topic = Fabricate(:topic, category: restricted_category)
      Fabricate(
        :browser_pageview_event,
        url: "/t/#{restricted_topic.slug}/#{restricted_topic.id}",
        session_id: "restricted-topic",
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :top_urls)).to include(
        include(value: nil, label: "Private or sensitive page", filterable: false),
      )
      expect(result.to_json).not_to include(restricted_topic.slug)
    end

    it "allows only public route shapes and redacts unknown, private, and guessed routes before aggregation" do
      topic = Fabricate(:topic)
      post = Fabricate(:post, topic: topic, post_number: 2)
      private_message = Fabricate(:private_message_topic)
      category = Fabricate(:category)
      published_page = Fabricate(:published_page, public: true)
      oversized_id = "9" * 100
      valid_paths = [
        "/about",
        "/top/weekly",
        "/posts.rss",
        "/t/#{topic.id}",
        "/t/#{topic.slug}/#{topic.id}",
        "/t/#{topic.slug}/#{topic.id}/#{post.post_number}",
        "/c/#{category.slug}/#{category.id}/l/top/monthly",
        published_page.path,
      ]
      secret_paths = [
        "/t/#{private_message.id}",
        "/t/#{private_message.slug}/#{private_message.id}",
        "/t/wrong-slug/#{topic.id}",
        "/c/wrong-slug/#{category.id}",
        "/activate-account/secret-token",
        "/email/unsubscribe/secret-token",
        "/associate/secret-token",
        "/uploads/private/secret.png",
        "/plugin/secret-route",
        "/new",
        "/u/someone/preferences",
        "/t/#{oversized_id}",
        "/t/oversized/#{oversized_id}/#{oversized_id}",
        "/c/oversized/#{oversized_id}",
      ]
      (valid_paths + secret_paths).each_with_index do |path, index|
        Fabricate(:browser_pageview_event, url: path, session_id: "classified-#{index}")
      end
      Fabricate(
        :browser_pageview_event,
        url: "#{Discourse.base_url}/about?token=absolute-secret",
        session_id: "classified-absolute",
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call
      rows = result.dig(:dimensions, :top_urls)
      filterable_paths = rows.select { |row| row[:filterable] }.map { |row| row[:value] }
      redacted_row = rows.find { |row| !row[:filterable] }
      hidden_request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
              url: "/t/#{private_message.id}",
            },
          ),
        )

      expect(filterable_paths).to contain_exactly(*valid_paths)
      expect(rows.find { |row| row[:value] == "/about" }).to include(pageviews: 2)
      expect(redacted_row).to include(value: nil, filterable: false, pageviews: secret_paths.size)
      expect(described_class.new(request: hidden_request).call.dig(:summary, :pageviews)).to eq(0)
      expect(result.to_json).not_to include(
        "secret-token",
        private_message.slug,
        "wrong-slug",
        "absolute-secret",
        oversized_id,
      )
    end

    it "uses only an external entry event's valid normalized host as traffic source" do
      Fabricate(
        :browser_pageview_event,
        url: "/entry",
        session_id: "source-session",
        normalized_referrer: "external.example/path",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: 2.minutes.ago,
      )
      Fabricate(
        :browser_pageview_event,
        url: "/later",
        session_id: "source-session",
        normalized_referrer: "bad host/path",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: 1.minute.ago,
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :traffic_sources)).to include(
        include(value: "external.example"),
      )
    end

    it "suppresses every exact canonical internal hostname alias without suppressing attacker domains" do
      Discourse.stubs(:current_hostname).returns("Site.Example")
      RailsMultisite::ConnectionManagement.stubs(:current_db_hostnames).returns(
        %w[site.example alias.example WWW.CASE.EXAMPLE. münchen.de],
      )
      referrers = {
        "site.example/path" => "internal-primary",
        "alias.example/path" => "internal-alias",
        "case.example/path" => "internal-case",
        "xn--mnchen-3ya.de/path" => "internal-idn",
        "site.example.attacker.test/path" => "external-suffix",
        "evilsite.example/path" => "external-prefix",
      }
      referrers.each do |referrer, session_id|
        Fabricate(
          :browser_pageview_event,
          session_id: session_id,
          normalized_referrer: referrer,
          normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        )
      end
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :traffic_sources)).to contain_exactly(
        include(value: "Direct / unknown", pageviews: 4),
        include(value: "site.example.attacker.test", pageviews: 1),
        include(value: "evilsite.example", pageviews: 1),
      )
      expect(result.dig(:analysis, :traffic_source_semantics)).to eq(
        "entry_external_normalized_host_v2",
      )
    end

    it "matches BrowserDetection family priority and exact browser filtering" do
      user_agents = {
        "edge" => "Mozilla Chrome/120 Safari/537.36 Edg/120",
        "opera" => "Mozilla Chrome/120 Safari/537.36 OPR/106",
        "firefox" => "Mozilla Firefox/120 Chrome/120",
        "chrome" => "Mozilla CriOS/120 Safari/537.36",
        "safari" => "Mozilla Safari/17",
        "ie" => "Mozilla Trident/7.0",
        "discoursehub" => "Discourse/163 CFNetwork/978.0.7",
        "unknown" => "CustomClient/1.0",
      }
      user_agents.each do |family, user_agent|
        Fabricate(
          :browser_pageview_event,
          session_id: "browser-#{family}",
          user_agent: user_agent,
          created_at: 1.hour.ago,
        )
      end
      params = {
        start_date: 1.day.ago.to_date.iso8601,
        end_date: Date.current.iso8601,
        filters: {
        },
      }

      unfiltered =
        described_class.new(
          request: described_class::Request.parse(ActionController::Parameters.new(params)),
        ).call
      edge_filtered =
        described_class.new(
          request:
            described_class::Request.parse(
              ActionController::Parameters.new(params.deep_merge(filters: { browser: "edge" })),
            ),
        ).call

      expect(
        unfiltered.dig(:dimensions, :browsers).map { |row| [row[:value], row[:label]] },
      ).to contain_exactly(*user_agents.keys.map { |family| [family, family] })
      expect(edge_filtered.dig(:summary, :pageviews)).to eq(1)
      expect(edge_filtered.dig(:filters, "browser")).to eq("edge")
      expect(unfiltered.dig(:analysis, :browser_classifier_semantics)).to eq("browser_detection_v1")
    end

    it "uses the dashboard crawler threshold and discloses the raw-event boundaries" do
      freeze_time(Time.zone.local(2026, 7, 31, 12))
      SiteSetting.improved_crawler_detection = true
      Fabricate(
        :browser_pageview_event,
        session_id: "scored-crawler",
        score: CrawlerScorer::BOT_SCORE_THRESHOLD + 1,
        created_at: 2.hours.ago,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "threshold-human",
        score: CrawlerScorer::BOT_SCORE_THRESHOLD,
        created_at: 90.minutes.ago,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "older-missing-score",
        score: nil,
        created_at: 1.hour.ago,
      )
      Fabricate(
        :browser_pageview_event,
        session_id: "delayed-missing-score",
        score: nil,
        created_at: 10.minutes.ago,
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      active_result = described_class.new(request: request).call
      SiteSetting.improved_crawler_detection = false
      disabled_result = described_class.new(request: request).call
      active_analysis = active_result.fetch(:analysis)
      disabled_analysis = disabled_result.fetch(:analysis)

      expect(active_analysis).to include(
        capture_scope: "retained_browser_pageviews",
        crawler_classification: "likely_crawler_score",
        crawler_classifier_semantics: "post_capture_likely_crawler_score_v3",
        request_detected_crawlers_included: false,
        dashboard_crawler_series_scope: "score_based_likely_crawlers_and_request_detected_crawlers",
        crawler_classifier_comparable_to_dashboard: true,
        crawler_series_comparable_to_dashboard: false,
        crawler_scoring_state: "active",
        crawler_scoring_delay_seconds: 30.minutes.to_i,
        crawler_scoring_delayed_event_count: 1,
        crawler_score_threshold: CrawlerScorer::BOT_SCORE_THRESHOLD,
        crawler_score_operator: "greater_than",
        unscored_event_count: 2,
        unscored_event_semantics: "no_persisted_crawler_score",
      )
      expect(active_result.fetch(:summary)).to include(
        pageviews: 4,
        anonymous_human_pageviews: 3,
        likely_crawler_pageviews: 1,
      )
      expect(disabled_result.fetch(:summary)).to include(
        anonymous_human_pageviews: 3,
        likely_crawler_pageviews: 1,
      )
      expect(disabled_analysis).to include(
        dashboard_crawler_series_scope: "request_detected_crawlers",
        crawler_classifier_comparable_to_dashboard: false,
        crawler_series_comparable_to_dashboard: false,
        crawler_scoring_state: "disabled",
      )
    end

    it "excludes an unsettled session until its first observed event crosses the settle cutoff" do
      freeze_time(Time.zone.local(2026, 7, 31, 12))
      Fabricate(:browser_pageview_event, session_id: "settling-session", created_at: 20.minutes.ago)
      BrowserPageviewSessionEngagement.create!(session_id: "settling-session", engaged_seconds: 18)
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      unsettled = described_class.new(request: request).call
      freeze_time(11.minutes.from_now)
      settled = described_class.new(request: request).call

      expect(unsettled.fetch(:summary)).to include(
        distinct_sessions: 0,
        bounce_rate: nil,
        average_session_duration_seconds: nil,
      )
      expect(unsettled.fetch(:analysis)).to include(
        session_scope: "capped_base_unfiltered",
        session_semantics_version: 2,
        session_semantics: "settled_first_observed_capped_base_v2",
        session_settle_seconds: 30.minutes.to_i,
        excluded_unsettled_session_count: 1,
      )
      expect(settled.fetch(:summary)).to include(
        distinct_sessions: 1,
        bounce_rate: 0,
        average_session_duration_seconds: 18,
      )
      expect(settled.dig(:analysis, :excluded_unsettled_session_count)).to eq(0)
    end

    it "rounds bounce rate to the nearest whole percent" do
      freeze_time(Time.zone.local(2026, 7, 31, 12))
      %w[bounced-one bounced-two engaged].each do |session_id|
        Fabricate(:browser_pageview_event, session_id: session_id, created_at: 1.hour.ago)
      end
      BrowserPageviewSessionEngagement.create!(session_id: "bounced-one", engaged_seconds: 0)
      BrowserPageviewSessionEngagement.create!(session_id: "bounced-two", engaged_seconds: 0)
      BrowserPageviewSessionEngagement.create!(session_id: "engaged", engaged_seconds: 20)
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      expect(described_class.new(request: request).call.fetch(:summary)).to include(
        distinct_sessions: 3,
        bounce_rate: 67,
        average_session_duration_seconds: 7,
      )
    end

    it "uses first observed capped events for entry data and discloses a mid-session cap boundary" do
      freeze_time(Time.zone.local(2026, 7, 31, 12))
      SiteSetting.admin_site_traffic_event_cap = 1
      Fabricate(
        :browser_pageview_event,
        url: "/about",
        session_id: "cap-boundary-session",
        normalized_referrer: "original.example/path",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: 2.hours.ago,
      )
      Fabricate(
        :browser_pageview_event,
        url: "/search",
        session_id: "cap-boundary-session",
        normalized_referrer: "later.example/path",
        normalized_referrer_version: BrowserPageviewReferrerInspector::VERSION,
        created_at: 1.hour.ago,
      )
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )

      result = described_class.new(request: request).call

      expect(result.dig(:dimensions, :entry_urls)).to contain_exactly(
        include(value: "/search", pageviews: 1, filterable: false),
      )
      expect(result.dig(:dimensions, :traffic_sources)).to contain_exactly(
        include(value: "later.example", pageviews: 1, filterable: false),
      )
      expect(result.fetch(:analysis)).to include(
        cap_truncated: true,
        session_start_semantics: "first_observed_event_in_capped_base",
        capped_slice_can_begin_mid_session: true,
        entry_event_semantics: "first_observed_event_in_capped_base",
        entry_cap_boundary_limited: true,
      )
    end
  end

  describe ".cache_key" do
    it "isolates site and semantic cache inputs" do
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      RailsMultisite::ConnectionManagement.stubs(:current_db).returns("first")
      first_key = described_class.cache_key(request: request, actor: actor)
      RailsMultisite::ConnectionManagement.stubs(:current_db).returns("second")
      second_key = described_class.cache_key(request: request, actor: actor)
      filtered_request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: request.start_date.iso8601,
            end_date: request.end_date.iso8601,
            filters: {
              country: "US",
            },
          ),
        )
      filtered_key = described_class.cache_key(request: filtered_request, actor: actor)
      SiteSetting.clean_up_browser_pageview_events = false
      cleanup_disabled_key = described_class.cache_key(request: request, actor: actor)
      SiteSetting.clean_up_browser_pageview_events = true
      cleanup_enabled_key = described_class.cache_key(request: request, actor: actor)
      SiteSetting.improved_crawler_detection = false
      crawler_detection_disabled_key = described_class.cache_key(request: request, actor: actor)
      SiteSetting.improved_crawler_detection = true
      crawler_detection_enabled_key = described_class.cache_key(request: request, actor: actor)

      expect(first_key).not_to eq(second_key)
      expect(first_key).not_to eq(filtered_key)
      expect(cleanup_disabled_key).not_to eq(cleanup_enabled_key)
      expect(crawler_detection_disabled_key).not_to eq(crawler_detection_enabled_key)
    end

    it "uses the resolved cutover only in the exact cache key" do
      request =
        described_class::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)

      first_exact_key =
        described_class.cache_key(
          request: request,
          actor: actor,
          cutover_date: Date.new(2026, 5, 1),
        )
      second_exact_key =
        described_class.cache_key(
          request: request,
          actor: actor,
          cutover_date: Date.new(2026, 5, 2),
        )

      first_coordination_key = described_class.coordination_key(request: request, actor: actor)
      BrowserPageviewEvent.stubs(:beacon_cutover_date).returns(Date.new(2026, 5, 3))
      second_coordination_key = described_class.coordination_key(request: request, actor: actor)

      expect(first_exact_key).not_to eq(second_exact_key)
      expect(first_coordination_key).to eq(second_coordination_key)
    end
  end

  describe ".event_cap" do
    it "uses the benchmark-derived finite hard maximum as the default" do
      expect(SiteSetting.admin_site_traffic_event_cap).to eq(1_000_000)
      expect(described_class.event_cap).to eq(1_000_000)
      expect(
        SiteSetting.type_supervisor.type_hash(:admin_site_traffic_event_cap).fetch(:max),
      ).to eq(1_000_000)

      SiteSetting.admin_site_traffic_event_cap = 1_000_000
      expect(described_class.event_cap).to eq(1_000_000)

      SiteSetting.stubs(:admin_site_traffic_event_cap).returns(1_000_001)
      expect(described_class.event_cap).to eq(1_000_000)
    end
  end

  describe AdminDashboardSiteTrafficDetail::CachedQuery do
    def yielding_executor(queries = [])
      Object.new.tap do |executor|
        executor.define_singleton_method(:execute) do |&operation|
          query =
            lambda do |sql:, binds: {}|
              queries << [sql, binds]
              []
            end
          operation.call(query)
        end
      end
    end

    def fixed_cutover_resolver(cutover_date = nil)
      Object.new.tap do |resolver|
        resolver.define_singleton_method(:resolve) { |query:| cutover_date }
      end
    end

    it "lets identical cold waiters outlast the SQL budget and use the computed cache entry" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      cache_values = {}
      cache_lock = Mutex.new
      cache = Object.new
      cache.define_singleton_method(:read) { |key| cache_lock.synchronize { cache_values[key] } }
      cache.define_singleton_method(:write) do |key, value, **|
        cache_lock.synchronize { cache_values[key] = value }
      end
      mutex = Mutex.new
      contended = Queue.new
      acquire_timeouts = Queue.new
      synchronizer = Object.new
      synchronizer.define_singleton_method(
        :synchronize,
      ) do |_key, validity:, acquire_timeout:, &block|
        acquire_timeouts << acquire_timeout
        raise DistributedMutex::LockTimeout if acquire_timeout <= 10.seconds

        contended << true if mutex.locked?
        mutex.synchronize(&block)
      end
      limiter = stub
      limiter.stubs(:performed!).returns(true)
      limiter_factory = stub
      limiter_factory.stubs(:new).returns(limiter)
      entered = Queue.new
      release = Queue.new
      computations = 0
      computation_lock = Mutex.new
      build_query =
        lambda do
          described_class.new(
            request: request,
            actor: actor,
            cache: cache,
            synchronizer: synchronizer,
            limiter_factory: limiter_factory,
            cache_key: "single-flight",
            executor: yielding_executor,
            cutover_resolver: fixed_cutover_resolver,
            compute:
              lambda do |**|
                computation_lock.synchronize { computations += 1 }
                entered << true
                release.pop
                { summary: { pageviews: 1 } }
              end,
          )
        end
      first = Thread.new { build_query.call.call }
      entered.pop
      second_started = Queue.new
      second =
        Thread.new do
          second_started << true
          build_query.call.call
        end
      second_started.pop
      contended.pop
      release << true

      expect([first.join(2), second.join(2)]).to all(be_a(Thread))
      expect([first.value, second.value]).to eq(
        [{ summary: { pageviews: 1 } }, { summary: { pageviews: 1 } }],
      )
      expect(computations).to eq(1)
      expect([acquire_timeouts.pop, acquire_timeouts.pop]).to eq([12.seconds, 12.seconds])
    end

    it "returns a cache hit without creating a limiter" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      cache = stub
      cache.stubs(:read).returns({ summary: { pageviews: 1 } })
      limiter_factory = stub
      limiter_factory.expects(:new).never
      queries = []
      resolver = Object.new
      resolver.define_singleton_method(:resolve) do |query:|
        query.call(sql: "cutover metadata")
        Date.new(2026, 5, 2)
      end

      result =
        described_class.new(
          request: request,
          actor: actor,
          cache: cache,
          limiter_factory: limiter_factory,
          cache_key: "cache-hit",
          executor: yielding_executor(queries),
          cutover_resolver: resolver,
          compute: ->(**) { raise "computed" },
        ).call

      expect(result).to eq(summary: { pageviews: 1 })
      expect(queries).to eq([["cutover metadata", {}]])
    end

    it "maps lock acquisition timeout without consuming quota, computing, or caching" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      cache = stub
      cache.stubs(:read).returns(nil)
      cache.expects(:write).never
      limiter_factory = stub
      limiter_factory.expects(:new).never
      synchronizer = stub
      synchronizer
        .expects(:synchronize)
        .with("lock-timeout:flight", validity: 30.seconds, acquire_timeout: 12.seconds)
        .raises(DistributedMutex::LockTimeout)
      executor = stub
      executor.expects(:execute).never

      expect do
        described_class.new(
          request: request,
          actor: actor,
          cache: cache,
          synchronizer: synchronizer,
          limiter_factory: limiter_factory,
          cache_key: "lock-timeout",
          executor: executor,
          cutover_resolver: fixed_cutover_resolver,
          compute: ->(**) { raise "computed" },
        ).call
      end.to raise_error(AdminDashboardSiteTrafficDetail::Timeout)
    end

    it "does not cache a failed computation and releases its read-only transaction" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      cache = stub
      cache.stubs(:read).returns(nil)
      cache.expects(:write).never
      limiter = stub
      limiter.expects(:performed!).once
      limiter_factory = stub
      limiter_factory.stubs(:new).returns(limiter)
      synchronizer = Object.new
      synchronizer.define_singleton_method(:synchronize) { |*, **, &block| block.call }
      resolver = Object.new
      resolver.define_singleton_method(:resolve) do |query:|
        query.call(sql: "SELECT CURRENT_DATE AS cutover_date").first.fetch("cutover_date")
      end
      connection = ActiveRecord::Base.connection
      original_transaction_depth = connection.open_transactions

      expect do
        described_class.new(
          request: request,
          actor: actor,
          cache: cache,
          synchronizer: synchronizer,
          limiter_factory: limiter_factory,
          cache_key: "failed-computation",
          cutover_resolver: resolver,
          compute:
            lambda do |query:, **|
              query.call(sql: "SELECT 1")
              raise "analytics failed"
            end,
        ).call
      end.to raise_error(RuntimeError, "analytics failed")

      expect(connection.open_transactions).to eq(original_transaction_depth)
      expect(connection.select_value("SELECT 1")).to eq(1)
    end

    it "does not cache a computed response when transaction exit fails" do
      request =
        AdminDashboardSiteTrafficDetail::Request.parse(
          ActionController::Parameters.new(
            start_date: 1.day.ago.to_date.iso8601,
            end_date: Date.current.iso8601,
            filters: {
            },
          ),
        )
      actor = Fabricate(:admin)
      cache = stub
      cache.stubs(:read).returns(nil)
      cache.expects(:write).never
      limiter = stub
      limiter.expects(:performed!).once
      limiter_factory = stub
      limiter_factory.stubs(:new).returns(limiter)
      executor = Object.new
      executor.define_singleton_method(:execute) do |&operation|
        query = ->(sql:, binds: {}) { [] }
        operation.call(query)
        raise "transaction exit failed"
      end

      expect do
        described_class.new(
          request: request,
          actor: actor,
          cache: cache,
          limiter_factory: limiter_factory,
          cache_key: "failed-transaction-exit",
          executor: executor,
          cutover_resolver: fixed_cutover_resolver,
          compute: ->(**) { { summary: { pageviews: 1 } } },
        ).call
      end.to raise_error(RuntimeError, "transaction exit failed")
    end
  end
end
