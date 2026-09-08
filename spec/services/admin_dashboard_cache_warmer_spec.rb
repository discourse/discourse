# frozen_string_literal: true

describe AdminDashboardCacheWarmer do
  before { Discourse.cache.clear }

  let(:prewarm_calls) { [] }
  let(:prewarming_provider) do
    calls = prewarm_calls
    Class.new(AdminDashboard::Reports::SourceProvider) do
      class << self
        def source_name = "prewarming_source"
      end

      define_singleton_method(:resolve_many) do |identifiers, guardian:|
        next {} if guardian.nil?

        identifiers.each_with_object({}) do |identifier, reports|
          reports[identifier] = AdminDashboard::Reports::ResolvedReport.new(
            source: source_name,
            identifier:,
            title: identifier,
            description: nil,
            label: nil,
            url: "",
          )
        end
      end

      define_singleton_method(:prewarm) do |identifiers, guardian:, filters:|
        calls << { identifiers:, guardian:, filters: }
      end
    end
  end
  let(:failing_provider) do
    Class.new(prewarming_provider) do
      class << self
        def source_name = "failing_source"

        def prewarm(...)
          raise StandardError, "prewarm failed"
        end
      end
    end
  end
  let(:plugin) { Plugin::Instance.new }

  before do
    DiscoursePluginRegistry.register_admin_dashboard_report_source(prewarming_provider, plugin)
    DiscoursePluginRegistry.register_admin_dashboard_report_source(failing_provider, plugin)
  end

  after do
    DiscoursePluginRegistry._raw_admin_dashboard_report_sources.reject! do |entry|
      [prewarming_provider, failing_provider].include?(entry[:value])
    end
  end

  def warmed_signups(offset)
    end_date = Time.zone.now.to_date + offset

    Report.find_cached(
      "signups",
      facets: %i[prev_period],
      start_date: (end_date - 29).beginning_of_day,
      end_date: end_date.end_of_day,
    )
  end

  describe ".call" do
    it "warms the default window for the server date and the neighbouring days" do
      described_class.call

      expect(warmed_signups(-1)).to be_present
      expect(warmed_signups(0)).to be_present
      expect(warmed_signups(1)).to be_present
    end

    it "warms the reports backing the highlights and engagement KPIs" do
      described_class.call

      types =
        described_class.report_specs.map do |spec|
          Report.find_cached(spec[:type], spec[:opts].merge(described_class.windows.second))
        end

      expect(types).to all(be_present)
    end

    it "asks report providers to warm their pinned reports for each default window" do
      AdminDashboardReport.create!(
        source: prewarming_provider.source_name,
        identifier: "report-id",
        position: 0,
      )

      described_class.call

      expect(prewarm_calls.map { |call| call[:identifiers] }).to eq(
        Array.new(described_class.windows.size, ["report-id"]),
      )
      expect(prewarm_calls.map { |call| call[:guardian].user }).to all(eq(Discourse.system_user))
      expect(prewarm_calls.map { |call| call[:filters] }).to eq(
        described_class.windows.map do |window|
          {
            start_date: window[:start_date].to_date.iso8601,
            end_date: window[:end_date].to_date.iso8601,
          }
        end,
      )
    end

    it "continues warming core reports when a pinned provider raises" do
      AdminDashboardReport.create!(
        source: failing_provider.source_name,
        identifier: "report-id",
        position: 0,
      )

      described_class.call

      expect([warmed_signups(-1), warmed_signups(0), warmed_signups(1)]).to all(be_present)
    end
  end

  describe ".report_specs" do
    it "requests the prev_period facet for KPI reports so keys match the dashboard" do
      kpi_specs =
        described_class.report_specs.reject { |spec| spec[:type] == "trust_level_pipeline" }

      expect(kpi_specs.map { |spec| spec[:opts] }.uniq).to eq([{ facets: %i[prev_period] }])
      expect(kpi_specs.map { |spec| spec[:type] }).to include(
        "signups",
        "dau_by_mau",
        "new_contributors",
        "daily_engaged_users",
      )
    end
  end
end
