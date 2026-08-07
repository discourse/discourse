# frozen_string_literal: true

describe AdminDashboardCacheWarmer do
  before { Discourse.cache.clear }

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
