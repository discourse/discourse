# frozen_string_literal: true

RSpec.describe AdminDashboard::Reports::CoreReportProvider do
  fab!(:admin)
  let(:guardian) { admin.guardian }

  describe ".source_name" do
    it "returns 'core_report'" do
      expect(described_class.source_name).to eq("core_report")
    end
  end

  describe ".label" do
    it "is nil because the standard provider's reports render without a pill" do
      expect(described_class.label).to be_nil
    end
  end

  describe ".resolve_many" do
    it "returns ResolvedReports for known built-in report identifiers" do
      result = described_class.resolve_many(%w[signups], guardian: guardian)

      expect(result.keys).to eq(%w[signups])
      resolved = result["signups"]
      expect(resolved).to be_a(AdminDashboard::Reports::ResolvedReport)
      expect(resolved.source).to eq("core_report")
      expect(resolved.identifier).to eq("signups")
      expect(resolved.title).to be_present
      expect(resolved.label).to be_nil
    end

    it "omits identifiers that don't correspond to a built-in report" do
      result = described_class.resolve_many(%w[totally_made_up], guardian: guardian)
      expect(result).to be_empty
    end

    it "handles mixed valid and invalid identifiers" do
      result = described_class.resolve_many(%w[signups fake_one], guardian: guardian)
      expect(result.keys).to eq(%w[signups])
    end

    it "accepts symbol identifiers" do
      result = described_class.resolve_many([:signups], guardian: guardian)
      expect(result.keys).to eq(%w[signups])
    end
  end

  describe ".list_all" do
    it "includes built-in reports" do
      reports = described_class.list_all

      expect(reports.map(&:identifier)).to include("signups")
      expect(reports).to all(be_a(AdminDashboard::Reports::ResolvedReport))
    end

    it "filters by name/description when search is given" do
      filtered = described_class.list_all(search: "signup")
      identifiers = filtered.map(&:identifier)

      expect(identifiers).to include("signups")
    end

    it "returns no results when search matches nothing" do
      expect(described_class.list_all(search: "zzzz_no_match_zzzz")).to be_empty
    end

    it "returns a title-sorted page and resumes after the cursor" do
      first_two = described_class.list_all(limit: 2)
      expect(first_two.size).to eq(2)

      titles = described_class.list_all.map { |report| report.title.to_s.downcase }
      expect(titles).to eq(titles.sort)

      after = { title: first_two.last.title, key: first_two.last.key }
      next_two = described_class.list_all(after: after, limit: 2)

      expect(next_two.size).to eq(2)
      expect(first_two.map(&:identifier)).not_to include(*next_two.map(&:identifier))
      expect(
        described_class.sort_key(next_two.first) <=> described_class.sort_key(first_two.last),
      ).to eq(1)
    end
  end

  describe "reports excluded from the dashboard" do
    after { Report.dashboard_excluded_report_types.delete("signups") }

    it "omits them from both list_all and resolve_many" do
      Report.dashboard_excluded_report_types << "signups"

      expect(described_class.list_all.map(&:identifier)).not_to include("signups")
      expect(described_class.resolve_many(%w[signups], guardian: guardian)).to be_empty
    end
  end

  describe ".fetch_many" do
    it "returns report payloads keyed by identifier" do
      result = described_class.fetch_many(%w[signups], guardian: guardian, filters: {})

      expect(result.keys).to eq(%w[signups])
      payload = result["signups"]
      expect(payload).to be_present
      expect(payload[:type]).to eq("signups")
    end

    it "skips identifiers that don't correspond to a built-in report" do
      result = described_class.fetch_many(%w[fake_one], guardian: guardian)
      expect(result).to be_empty
    end

    it "scopes report data to the provided date range" do
      Discourse.cache.clear
      freeze_time(Time.utc(2026, 2, 15)) do
        Fabricate(:user, created_at: Time.utc(2026, 1, 5))
        Fabricate(:user, created_at: Time.utc(2026, 1, 5))
        Fabricate(:user, created_at: Time.utc(2026, 1, 25))
        Fabricate(:user, created_at: Time.utc(2026, 2, 10))

        in_range =
          described_class.fetch_many(
            %w[signups],
            guardian: guardian,
            filters: {
              start_date: "2026-01-01",
              end_date: "2026-01-31",
            },
          )

        out_of_range =
          described_class.fetch_many(
            %w[signups],
            guardian: guardian,
            filters: {
              start_date: "2026-03-01",
              end_date: "2026-03-31",
            },
          )

        in_range_points = in_range["signups"][:data].map { |point| [point[:x].to_date, point[:y]] }
        expect(in_range_points).to contain_exactly(
          [Date.new(2026, 1, 5), 2],
          [Date.new(2026, 1, 25), 1],
        )

        expect(out_of_range["signups"][:data]).to be_empty
      end
    end
  end

  describe "registration" do
    it "is registered as a core provider on boot" do
      expect(AdminDashboard::Reports::Registry::CORE_PROVIDERS).to include(described_class)
    end

    it "is discoverable via Registry.provider_for" do
      expect(AdminDashboard::Reports::Registry.provider_for("core_report")).to eq(described_class)
    end
  end
end
