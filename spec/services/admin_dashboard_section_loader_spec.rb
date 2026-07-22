# frozen_string_literal: true

require "rack-mini-profiler"
require "rack_mini_profiler_sql_collector"

RSpec.describe AdminDashboardSectionLoader do
  fab!(:admin)

  after do
    if thread_pool = described_class.instance_variable_get(:@thread_pool)
      thread_pool.shutdown
      thread_pool.wait_for_termination(timeout: 1)
      described_class.remove_instance_variable(:@thread_pool)
    end
  end

  describe ".build" do
    it "ensures the sections are built in order with current user and dates" do
      AdminDashboardSiteTraffic
        .expects(:build)
        .with do |kwargs|
          kwargs[:start_date] == "2026-05-01" && kwargs[:end_date] == "2026-05-07" &&
            kwargs[:guardian].is_a?(Guardian) && kwargs[:guardian].user.id == admin.id
        end
        .returns({ value: "traffic" })
      AdminDashboardEngagement
        .expects(:build)
        .with(start_date: "2026-05-01", end_date: "2026-05-07", current_user: admin)
        .returns({ value: "engagement" })
      AdminDashboardSearch
        .expects(:build)
        .with(start_date: "2026-05-01", end_date: "2026-05-07")
        .returns({ value: "search" })

      expect(
        described_class.build(
          section_ids: %w[traffic engagement search],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq(
        [
          { id: "traffic", data: { value: "traffic" } },
          { id: "engagement", data: { value: "engagement" } },
          { id: "search", data: { value: "search" } },
        ],
      )
    end

    it "runs independent plugin sections concurrently off the request thread while preserving order and failures" do
      started_sections = Queue.new
      release_sections = Queue.new
      loader_threads = Queue.new
      section_loader =
        lambda do |start_date:, end_date:, current_user:|
          loader_threads << Thread.current
          started_sections << current_user.id
          release_sections.pop
          { start_date: start_date, end_date: end_date }
        end
      failing_loader = ->(**) { raise StandardError, "boom" }
      described_class.stubs(:pool_size).returns(3)
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [
          { id: "second", enabled: -> { true }, loader: section_loader },
          { id: "first", enabled: -> { true }, loader: section_loader },
          { id: "failing", enabled: -> { true }, loader: failing_loader },
        ],
      )
      Discourse.stubs(:warn_exception)

      builder_thread =
        Thread.new do
          described_class.build(
            section_ids: %w[first failing second],
            current_user: admin,
            start_date: "2026-05-01",
            end_date: "2026-05-07",
          )
        end

      2.times { expect(started_sections.pop).to eq(admin.id) }
      2.times { release_sections << true }
      result = builder_thread.value
      worker_threads = 2.times.map { loader_threads.pop }

      expect(result).to eq(
        [
          { id: "first", data: { start_date: "2026-05-01", end_date: "2026-05-07" } },
          { id: "failing", data: nil, error: true },
          { id: "second", data: { start_date: "2026-05-01", end_date: "2026-05-07" } },
        ],
      )
      expect(worker_threads).to all(be_a(Thread))
      expect(worker_threads).not_to include(builder_thread)
    end

    it "runs section loaders on the request thread when parallel mode is disabled" do
      loader_thread = nil
      loader =
        lambda do |start_date:, end_date:, current_user:|
          loader_thread = Thread.current
          { value: current_user.id }
        end
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [{ id: "profiled", enabled: -> { true }, loader: loader }],
      )

      expect(
        described_class.build(
          section_ids: ["profiled"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
          parallel: false,
        ),
      ).to eq([{ id: "profiled", data: { value: admin.id } }])
      expect(loader_thread).to eq(Thread.current)
    end
  end

  describe "plugin sections" do
    it "routes a registered plugin section id to its loader block" do
      loader = ->(start_date:, end_date:, current_user:) do
        { value: "support", user: current_user.id }
      end
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [{ id: "support", enabled: -> { true }, loader: loader }],
      )

      expect(
        described_class.build(
          section_ids: ["support"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "support", data: { value: "support", user: admin.id } }])
    end

    it "returns nil data for an unknown section id" do
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns([])

      expect(
        described_class.build(
          section_ids: ["frobnitz"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "frobnitz", data: nil }])
    end
  end

  describe "rack-mini-profiler SQL collection" do
    after { Rack::MiniProfiler.current = nil }

    it "replays worker SQL once on the parent request and keeps concurrent requests isolated" do
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [
          {
            id: "sql",
            enabled: -> { true },
            loader:
              lambda do |start_date:, end_date:, current_user:|
                ActiveRecord::Base.connection.exec_query(
                  "SELECT 1 AS tagged_active_record_#{current_user.id}",
                )
                DB.query_single("SELECT 1 AS tagged_minisql_#{current_user.id}")
                DB.query_single("SELECT 1 AS repeated_sql_#{current_user.id}")
                DB.query_single("SELECT 1 AS repeated_sql_#{current_user.id}")
                { value: current_user.id }
              end,
          },
        ],
      )
      results = Queue.new

      [Fabricate(:admin), Fabricate(:admin)].each do |request_admin|
        Thread.new do
          Rack::MiniProfiler.create_current(
            "REQUEST_METHOD" => "GET",
            "PATH_INFO" => "/admin/dashboard.json",
          )
          described_class.build(
            section_ids: ["sql"],
            current_user: request_admin,
            start_date: "2026-05-01",
            end_date: "2026-05-07",
          )
          sql = profiler_sql_strings
          Rack::MiniProfiler.current = nil
          results << [request_admin.id, sql]
        end
      end

      first_id, first_sql = results.pop
      second_id, second_sql = results.pop

      expect(first_sql.grep(/tagged_active_record_#{first_id}/).size).to eq(1)
      expect(first_sql.grep(/tagged_minisql_#{first_id}/).size).to eq(1)
      expect(first_sql.grep(/repeated_sql_#{first_id}/).size).to eq(2)
      expect(
        first_sql.grep(
          /tagged_active_record_#{second_id}|tagged_minisql_#{second_id}|repeated_sql_#{second_id}/,
        ),
      ).to be_empty
      expect(second_sql.grep(/tagged_active_record_#{second_id}/).size).to eq(1)
      expect(second_sql.grep(/tagged_minisql_#{second_id}/).size).to eq(1)
      expect(second_sql.grep(/repeated_sql_#{second_id}/).size).to eq(2)
      expect(
        second_sql.grep(
          /tagged_active_record_#{first_id}|tagged_minisql_#{first_id}|repeated_sql_#{first_id}/,
        ),
      ).to be_empty
    end

    it "replays SQL collected before a failed section and cleans up pool threads" do
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [
          {
            id: "failing_sql",
            enabled: -> { true },
            loader:
              lambda do |**|
                DB.query_single("SELECT 1 AS sql_before_failure")
                raise StandardError, "boom"
              end,
          },
        ],
      )
      Discourse.stubs(:warn_exception)
      Rack::MiniProfiler.create_current(
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/admin/dashboard.json",
      )

      expect(
        described_class.build(
          section_ids: ["failing_sql"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "failing_sql", data: nil, error: true }])
      first_request_sql = profiler_sql_strings
      Rack::MiniProfiler.current = nil

      DB.query_single("SELECT 1 AS sql_after_profiler_request")
      Rack::MiniProfiler.create_current(
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/admin/dashboard.json",
      )
      Rack::MiniProfiler.record_sql("SELECT 1 AS parent_request_only", 1.0)
      second_request_sql = profiler_sql_strings

      expect(first_request_sql.grep(/sql_before_failure/).size).to eq(1)
      expect(second_request_sql.grep(/sql_before_failure|sql_after_profiler_request/)).to be_empty
      expect(second_request_sql.grep(/parent_request_only/).size).to eq(1)
    end

    it "accepts reader duration reports from PG results captured in workers" do
      DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
        [
          {
            id: "reader",
            enabled: -> { true },
            loader:
              lambda do |**|
                ActiveRecord::Base
                  .connection
                  .raw_connection
                  .exec("SELECT 1 AS reader_duration_query")
                  .values
                { value: "read" }
              end,
          },
        ],
      )
      Rack::MiniProfiler.create_current(
        "REQUEST_METHOD" => "GET",
        "PATH_INFO" => "/admin/dashboard.json",
      )

      expect(
        described_class.build(
          section_ids: ["reader"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq([{ id: "reader", data: { value: "read" } }])

      expect(profiler_sql_strings.grep(/reader_duration_query/).size).to eq(1)
    end
  end

  describe ".pool_size" do
    it "caps at the DB connection pool, reserving one for the request thread" do
      ActiveRecord::Base.connection_pool.stubs(:size).returns(3)
      expect(described_class.pool_size).to eq(2)
    end

    it "uses the desired count when the pool has room to spare" do
      ActiveRecord::Base.connection_pool.stubs(:size).returns(100)
      desired =
        AdminDashboardSectionConfiguration::KNOWN_SECTIONS.size +
          DiscoursePluginRegistry.admin_dashboard_sections.size
      expect(described_class.pool_size).to eq(desired)
    end

    it "never drops below one" do
      ActiveRecord::Base.connection_pool.stubs(:size).returns(1)
      expect(described_class.pool_size).to eq(1)
    end
  end

  def profiler_sql_strings
    Rack::MiniProfiler.current.page_struct[:root].sql_timings.map do |timing|
      CGI.unescapeHTML(timing[:formatted_command_string].to_s)
    end
  end
end

RSpec.describe AdminDashboardSectionLoader do
  self.use_transactional_tests = false

  after do
    if thread_pool = described_class.instance_variable_get(:@thread_pool)
      thread_pool.shutdown
      thread_pool.wait_for_termination(timeout: 1)
      described_class.remove_instance_variable(:@thread_pool)
    end
  end

  it "returns database connections to the pool once a section finishes building" do
    worker_thread = nil
    loader =
      lambda do |start_date:, end_date:, current_user:|
        worker_thread = Thread.current
        ActiveRecord::Base.connection.execute("SELECT 1")
        { value: "leaky" }
      end
    DiscoursePluginRegistry.stubs(:admin_dashboard_sections).returns(
      [{ id: "leaky", enabled: -> { true }, loader: loader }],
    )

    described_class.build(
      section_ids: ["leaky"],
      current_user: Discourse.system_user,
      start_date: "2026-05-01",
      end_date: "2026-05-07",
    )

    expect(worker_thread).not_to eq(Thread.current)
    wait_for do
      ActiveRecord::Base.connection_pool.connections.none? do |connection|
        connection.owner == worker_thread
      end
    end
  end
end
