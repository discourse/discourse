# frozen_string_literal: true

require "rack-mini-profiler"
require "patches/db/pg"
require "rack_mini_profiler_async_sql"
RackMiniProfilerAsyncSql.install

RSpec.describe AdminDashboardSearch, type: :request do
  self.use_transactional_tests = false

  before do
    SiteSetting.log_search_queries = true
    SearchLog.delete_all
  end

  after do
    SearchLog.delete_all
    ApplicationRequest.delete_all
    UserVisit.delete_all
  end

  def create_search_log(term:, created_at:, search_result_id: nil)
    SearchLog.create!(
      term: term,
      user_id: user_record.id,
      ip_address: "127.0.0.1",
      created_at: created_at,
      search_result_id: search_result_id,
      search_type: SearchLog.search_types[:header],
    )
  end

  def user_record
    Discourse.system_user
  end

  def async_sql_events
    events = []
    subscriber =
      ActiveSupport::Notifications.subscribe(
        "sql.active_record",
      ) do |_name, start, finish, _id, payload|
        events << { start: start, finish: finish, sql: payload[:sql] } if payload[:async]
      end

    yield events
  ensure
    ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
  end

  def profile_sql_for(path)
    Rack::MiniProfiler.create_current("PATH_INFO" => path, "REQUEST_METHOD" => "GET")
    ActiveSupport::Executor.wrap { ActiveRecord::Base.uncached { yield } }
    Rack::MiniProfiler.current.page_struct.root.sql_timings.map do |timing|
      timing[:formatted_command_string]
    end
  ensure
    Rack::MiniProfiler.current = nil if defined?(Rack::MiniProfiler)
  end

  def with_async_capacity
    original_configuration = ActiveRecord::Base.connection_db_config.configuration_hash
    original_executor = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = :multi_thread_pool
    ActiveRecord::Base.establish_connection(original_configuration.merge(pool: 5, max_threads: 4))
    yield
  ensure
    ActiveRecord::Base.establish_connection(original_configuration) if original_configuration
    ActiveRecord.async_query_executor = original_executor if original_executor
  end

  def with_sync_queries
    original_configuration = ActiveRecord::Base.connection_db_config.configuration_hash
    original_executor = ActiveRecord.async_query_executor
    ActiveRecord.async_query_executor = nil
    ActiveRecord::Base.establish_connection(original_configuration.merge(max_threads: 0))
    yield
  ensure
    ActiveRecord::Base.establish_connection(original_configuration) if original_configuration
    ActiveRecord.async_query_executor = original_executor if original_executor
  end

  def async_select(sql)
    ActiveRecord::Base.connection.select_all(sql, "SQL", [], async: true).then(&:to_a)
  end

  def tagged_count(sql, tag)
    sql.count { |statement| statement.include?(tag) }
  end

  describe ".build" do
    it "reserves caller connection capacity in database async executor configuration" do
      configuration = Rails.application.config.database_configuration.fetch(Rails.env)

      expect(configuration["max_threads"]).to eq(configuration["pool"] - 1)
      expect(ActiveRecord.async_query_executor).to eq(:multi_thread_pool)
      configured_threads =
        [1, 2, 5, 8].map do |pool_size|
          GlobalSetting.stubs(:db_pool).returns(pool_size)
          GlobalSetting.database_config.fetch("production").fetch("max_threads")
        end
      expect(configured_threads).to eq([0, 1, 4, 7])
    end

    it "attributes known sync, MiniSql, plugin, and pre-failure SQL exactly once per concurrent profiler context" do
      request_tags = %w[dashboard-request-one dashboard-request-two]
      dashboard_user = user_record
      original_configuration = ActiveRecord::Base.connection_db_config.configuration_hash
      original_executor = ActiveRecord.async_query_executor
      ActiveRecord.async_query_executor = :multi_thread_pool
      ActiveRecord::Base.establish_connection(original_configuration.merge(pool: 5, max_threads: 4))
      original_sections = DiscoursePluginRegistry._raw_admin_dashboard_sections.dup
      plugin = Class.new { def enabled? = true }.new
      request_tags.each do |request_tag|
        DiscoursePluginRegistry._raw_admin_dashboard_sections << {
          plugin: plugin,
          value: {
            id: "#{request_tag}-plugin",
            enabled: -> { true },
            loader:
              lambda do |start_date:, end_date:, current_user:|
                User.where("id = ? /* #{request_tag}-sync-ar */", current_user.id).pluck(:id)
                DB.query_single("SELECT 1 /* #{request_tag}-minisql */")
                { value: current_user.id }
              end,
          },
        }
        DiscoursePluginRegistry._raw_admin_dashboard_sections << {
          plugin: plugin,
          value: {
            id: "#{request_tag}-failed",
            enabled: -> { true },
            loader:
              lambda do |start_date:, end_date:, current_user:|
                DB.query_single("SELECT 1 /* #{request_tag}-pre-failure */")
                raise StandardError, "#{request_tag} failure"
              end,
          },
        }
      end
      Discourse.stubs(:warn_exception)
      results = Queue.new

      threads =
        request_tags.map do |request_tag|
          Thread.new do
            sql =
              profile_sql_for("/admin/dashboard.json?#{request_tag}") do
                ActiveRecord::Base
                  .connection
                  .select_all("SELECT 1 /* #{request_tag}-async-ar */", "SQL", [], async: true)
                  .then(&:to_a)
                  .value
                AdminDashboardSectionLoader.build(
                  section_ids: ["#{request_tag}-plugin", "#{request_tag}-failed"],
                  current_user: dashboard_user,
                  start_date: 7.days.ago.iso8601,
                  end_date: Time.zone.today.iso8601,
                )
              end
            results << [request_tag, sql]
          end
        end
      threads.each(&:join)

      sql_by_tag = {}
      request_tags.size.times do
        request_tag, sql = results.pop
        sql_by_tag[request_tag] = sql
      end

      request_tags.each do |request_tag|
        sql = sql_by_tag.fetch(request_tag)
        expect(tagged_count(sql, "#{request_tag}-sync-ar")).to eq(1)
        expect(tagged_count(sql, "#{request_tag}-minisql")).to eq(1)
        expect(tagged_count(sql, "#{request_tag}-async-ar")).to eq(1)
        expect(tagged_count(sql, "#{request_tag}-pre-failure")).to eq(1)
        other_tag = (request_tags - [request_tag]).first
        expect(sql.join("\n")).not_to include(other_tag)
      end

      expect(
        ActiveRecord::Base.connection_pool.with_connection do |connection|
          connection.select_value("SELECT 1")
        end,
      ).to eq(1)
    ensure
      if original_sections
        DiscoursePluginRegistry._raw_admin_dashboard_sections.replace(original_sections)
      end
      ActiveRecord::Base.establish_connection(original_configuration) if original_configuration
      ActiveRecord.async_query_executor = original_executor if original_executor
    end

    it "records async SQL after production subscriber removal and install" do
      original_notifier = ActiveSupport::Notifications.notifier
      ActiveSupport::Notifications.notifier = ActiveSupport::Notifications::Fanout.new
      RackMiniProfilerAsyncSql.install
      ActiveSupport::Notifications.notifier.unsubscribe("sql.active_record")
      RackMiniProfilerAsyncSql.install

      sql =
        with_async_capacity do
          profile_sql_for("/admin/dashboard.json?production-order") do
            async_select("SELECT 1 /* production-order-async */").value
          end
        end

      expect(tagged_count(sql, "production-order-async")).to eq(1)
    ensure
      ActiveSupport::Notifications.notifier = original_notifier if original_notifier
      RackMiniProfilerAsyncSql.install
    end

    it "records repeated async SQL occurrences while avoiding caller-runs duplicates" do
      repeated_sql =
        with_async_capacity do
          profile_sql_for("/admin/dashboard.json?repeated-async") do
            2.times do
              ActiveRecord::Base
                .connection
                .select_all("SELECT 1 /* repeated-async-sql */", "SQL", [], async: true)
                .then(&:to_a)
                .value
            end
          end
        end
      sync_then_async_sql =
        with_async_capacity do
          profile_sql_for("/admin/dashboard.json?sync-then-async") do
            ActiveRecord::Base.connection.execute("SELECT 1 /* sync-then-async-sql */")
            ActiveRecord::Base
              .connection
              .select_all("SELECT 1 /* sync-then-async-sql */", "SQL", [], async: true)
              .then(&:to_a)
              .value
          end
        end

      executor = ActiveRecord::Base.connection_pool.async_executor
      executor.stubs(:post).yields
      caller_runs_sql =
        profile_sql_for("/admin/dashboard.json?caller-runs") do
          2.times { User.where("id >= 0 /* caller-runs-async */").async_count.value }
        end

      expect(tagged_count(repeated_sql, "repeated-async-sql")).to eq(2)
      expect(tagged_count(sync_then_async_sql, "sync-then-async-sql")).to eq(2)
      expect(tagged_count(caller_runs_sql, "caller-runs-async")).to eq(2)
    end

    it "records ordinary synchronous AR and MiniSql profiler SQL without duplicates" do
      sql =
        profile_sql_for("/t/ordinary-topic") do
          User.where("id = ? /* ordinary-sync-ar */", user_record.id).pluck(:id)
          DB.query_single("SELECT 1 /* ordinary-minisql */")
        end
      expect(tagged_count(sql, "ordinary-sync-ar")).to eq(1)
      expect(tagged_count(sql, "ordinary-minisql")).to eq(1)
    end

    it "returns the same complete search payload with async and sync queries" do
      create_search_log(term: "ruby", created_at: 2.days.ago, search_result_id: 1)
      2.times { create_search_log(term: "ruby", created_at: 2.days.ago) }
      create_search_log(term: "ghost", created_at: 3.days.ago)
      create_search_log(term: "prior", created_at: 10.days.ago)

      sync_result =
        with_sync_queries do
          AdminDashboardSearch.build(
            start_date: 7.days.ago.iso8601,
            end_date: Time.zone.today.iso8601,
          )
        end
      async_result =
        with_async_capacity do
          AdminDashboardSearch.build(
            start_date: 7.days.ago.iso8601,
            end_date: Time.zone.today.iso8601,
          )
        end

      expect(async_result).to eq(sync_result)
    end

    it "returns the same complete site traffic payload with async and sync queries" do
      SiteSetting.persist_browser_pageview_events = false
      Fabricate(:logged_in_browser_application_request, date: 2.days.ago.to_date, count: 5)
      Fabricate(:anonymous_browser_application_request, date: 2.days.ago.to_date, count: 7)
      Fabricate(:crawler_application_request, date: 1.day.ago.to_date, count: 3)
      Fabricate(:logged_in_browser_application_request, date: 10.days.ago.to_date, count: 2)

      sync_result =
        with_sync_queries do
          AdminDashboardSiteTraffic.build(
            start_date: 7.days.ago.iso8601,
            end_date: Time.zone.today.iso8601,
            guardian: Guardian.new(user_record),
          )
        end
      async_result =
        with_async_capacity do
          AdminDashboardSiteTraffic.build(
            start_date: 7.days.ago.iso8601,
            end_date: Time.zone.today.iso8601,
            guardian: Guardian.new(user_record),
          )
        end

      expect(async_result).to eq(sync_result)
    end

    it "drains search async query siblings after an early failure" do
      2.times { |index| create_search_log(term: "drain-#{index}", created_at: 2.days.ago) }

      with_async_capacity do
        start_date = 7.days.ago.beginning_of_day
        end_date = Time.zone.today.end_of_day

        async_sql_events do |events|
          failing_stats = async_select("SELECT invalid_column /* search-drain-failure */")
          sibling_stats = async_select("SELECT 1 /* search-drain-sibling-stats */")
          AdminDashboardSearch
            .any_instance
            .stubs(:async_window_stats)
            .returns(failing_stats, sibling_stats)

          expect do
            AdminDashboardSearch.build(start_date: start_date.iso8601, end_date: end_date.iso8601)
          end.to raise_error(ActiveRecord::StatementInvalid)

          matching_sql = events.map { |event| event[:sql] }.join("\n")
          expect(
            tagged_count(events.map { |event| event[:sql] }, "search-drain-sibling-stats"),
          ).to eq(1)
          expect(matching_sql.scan(/search_logs/).size).to be >= 2
          expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
        end
      end
    end

    it "drains site traffic async query siblings after an early failure" do
      with_async_capacity do
        async_sql_events do |events|
          failing_rows = async_select("SELECT invalid_column /* traffic-drain-failure */")
          sibling_rows = async_select("SELECT 1 AS value /* traffic-drain-sibling */")
          AdminDashboardSiteTraffic
            .any_instance
            .stubs(:async_traffic_rows)
            .returns(failing_rows, sibling_rows)

          expect do
            AdminDashboardSiteTraffic.build(
              start_date: 7.days.ago.iso8601,
              end_date: Time.zone.today.iso8601,
              guardian: Guardian.new(user_record),
            )
          end.to raise_error(ActiveRecord::StatementInvalid)

          expect(tagged_count(events.map { |event| event[:sql] }, "traffic-drain-sibling")).to eq(1)
          expect(ActiveRecord::Base.connection.select_value("SELECT 1")).to eq(1)
        end
      end
    end

    it "proves real search builder async query intervals overlap when worker capacity is available" do
      4.times { |index| create_search_log(term: "overlap-#{index}", created_at: 2.days.ago) }
      original_configuration = ActiveRecord::Base.connection_db_config.configuration_hash
      original_executor = ActiveRecord.async_query_executor
      ActiveRecord.async_query_executor = :multi_thread_pool
      ActiveRecord::Base.establish_connection(original_configuration.merge(pool: 5, max_threads: 4))

      SearchLog.stubs(:non_staff).returns(
        SearchLog.from("search_logs, pg_sleep(0.1)").where(user_id: user_record.id),
      )

      async_sql_events do |events|
        result =
          AdminDashboardSearch.build(
            start_date: 7.days.ago.iso8601,
            end_date: Time.zone.today.iso8601,
          )
        search_events = events.select { |event| event[:sql].include?("search_logs") }
        intervals_overlap =
          search_events
            .combination(2)
            .any? do |first, second|
              first[:start] < second[:finish] && second[:start] < first[:finish]
            end

        expect(result[:logging_enabled]).to eq(true)
        expect(search_events.size).to be >= 2
        expect(intervals_overlap).to eq(true)
      end
    ensure
      ActiveRecord::Base.establish_connection(original_configuration) if original_configuration
      ActiveRecord.async_query_executor = original_executor if original_executor
    end

    it "emits async SQL from actual site traffic builder queries when worker capacity is available" do
      with_async_capacity do
        async_sql_events do |events|
          result =
            AdminDashboardSiteTraffic.build(
              start_date: 7.days.ago.iso8601,
              end_date: Time.zone.today.iso8601,
              guardian: Guardian.new(user_record),
            )

          expect(result[:pageview_series]).to be_present
          expect(
            events.count do |event|
              event[:sql].include?("Admin Dashboard Traffic") ||
                event[:sql].include?("generate_series")
            end,
          ).to be >= 2
        end
      end
    end

    it "does not emit async SQL from dashboard-shared reports outside dashboard async callers" do
      async_sql_events do |events|
        %w[
          trust_level_pipeline
          posters_by_member_type
          activity_by_category
          page_view_total_reqs
        ].each do |type|
          Report.find(
            type,
            start_date: 7.days.ago,
            end_date: Time.zone.now,
            current_user: user_record,
          )
        end

        expect(events).to be_empty
      end
    end

    it "records async Active Record SQL once in the current profiler context" do
      create_search_log(term: "profiled", created_at: 2.days.ago)

      sql =
        with_async_capacity do
          profile_sql_for("/admin/dashboard.json") do
            AdminDashboardSearch.build(
              start_date: 7.days.ago.iso8601,
              end_date: Time.zone.today.iso8601,
            )
          end
        end
      search_sql = sql.grep(/search_logs/)

      expect(sql).to be_present
      expect(search_sql.size).to eq(search_sql.uniq.size)
      expect(search_sql.size).to be >= 2
    end

    it "does not introduce async SQL in representative admin report request and report export job contexts" do
      admin = Discourse.system_user
      sign_in(admin)
      async_sql_events do |events|
        get "/admin/reports/trust_level_pipeline.json"
        expect(response.status).to eq(200)

        job = Jobs::ExportCsvFile.new
        job.extra = {
          name: "trust_level_pipeline",
          start_date: 7.days.ago.iso8601,
          end_date: Time.zone.today.iso8601,
        }
        job.current_user = admin
        rows = []
        job.report_export { |row| rows << row }
        expect(rows).to be_present
        expect(events).to be_empty
      end
    end
  end
end
