# frozen_string_literal: true

describe AdminDashboardSectionLoader do
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

    it "includes report card payloads in the reports section data" do
      provider =
        Class.new(AdminDashboard::Reports::SourceProvider) do
          def self.source_name = "section_loader_test"
          def self.label = "Test"

          def self.resolve_many(identifiers, guardian:)
            identifiers.index_with do |identifier|
              AdminDashboard::Reports::ResolvedReport.new(
                source: source_name,
                identifier: identifier.to_s,
                title: "Report #{identifier}",
                description: nil,
                label: label,
                url: "/reports/#{identifier}",
              )
            end
          end

          def self.fetch_many(identifiers, guardian:, filters:)
            identifiers.index_with { |identifier| { identifier:, filters: } }
          end
        end
      plugin = Plugin::Instance.new
      DiscoursePluginRegistry.register_admin_dashboard_report_source(provider, plugin)
      AdminDashboardReport.delete_all
      AdminDashboardReport.create!(
        source: provider.source_name,
        identifier: "activity",
        position: 0,
      )

      result =
        described_class.build(
          section_ids: ["reports"],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        )

      expect(result).to eq(
        [
          {
            id: "reports",
            data: {
              items: [
                {
                  source: provider.source_name,
                  identifier: "activity",
                  title: "Report activity",
                  description: nil,
                  label: "Test",
                  url: "/reports/activity",
                  key: "#{provider.source_name}:activity",
                  payload: {
                    identifier: "activity",
                    filters: {
                      start_date: "2026-05-01",
                      end_date: "2026-05-07",
                    },
                  },
                },
              ],
            },
          },
        ],
      )
    ensure
      DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
        entry[:value] == provider
      end
    end

    it "returns partial section data when a section fails to build" do
      error = StandardError.new("boom")
      AdminDashboardSiteTraffic.stubs(:build).returns({ value: "traffic" })
      AdminDashboardSearch.stubs(:build).raises(error)
      Discourse.expects(:warn_exception).with(
        error,
        message: "Failed to build admin dashboard section",
        env: {
          section_id: "search",
        },
      )

      expect(
        described_class.build(
          section_ids: %w[traffic search],
          current_user: admin,
          start_date: "2026-05-01",
          end_date: "2026-05-07",
        ),
      ).to eq(
        [{ id: "traffic", data: { value: "traffic" } }, { id: "search", data: nil, error: true }],
      )
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
end

describe AdminDashboardSectionLoader do
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
    loader = ->(start_date:, end_date:, current_user:) do
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
      ActiveRecord::Base.connection_pool.connections.none? { |c| c.owner == worker_thread }
    end
  end
end
