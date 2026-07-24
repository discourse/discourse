# frozen_string_literal: true

describe AdminDashboardHighlights do
  describe ".build" do
    before do
      freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0))
      Discourse.cache.clear
    end

    it "returns a kpis array keyed by report type" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

      expect(result[:kpis]).to be_an(Array)
      types = result[:kpis].map { |k| k[:type] }
      expect(types).to include(:new_signups, :dau_mau, :new_contributors)
    end

    it "computes value, previous_value and percent_change for new_signups" do
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 10))
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 15))
      Fabricate(:user, created_at: Time.zone.local(2026, 3, 10))

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      signups = result[:kpis].find { |k| k[:type] == :new_signups }

      expect(signups[:value]).to eq(2)
      expect(signups[:previous_value]).to eq(1)
      expect(signups[:percent_change]).to eq(100.0)
    end

    it "emits report_type and report_query instead of a synthesised URL" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      signups = result[:kpis].find { |k| k[:type] == :new_signups }

      expect(signups[:report_type]).to eq("signups")
      expect(signups[:report_query]).to eq(start_date: "2026-04-01", end_date: "2026-04-28")
      expect(signups).not_to have_key(:report_url)
    end

    it "returns nil percent_change when previous is zero" do
      Fabricate(:user, created_at: Time.zone.local(2026, 4, 10))

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      signups = result[:kpis].find { |k| k[:type] == :new_signups }

      expect(signups[:percent_change]).to be_nil
    end

    it "returns nil value when the report has no data points" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      dau = result[:kpis].find { |k| k[:type] == :dau_mau }

      expect(dau[:value]).to be_nil
    end

    it "averages dau_mau values rather than summing them when there is data" do
      Fabricate(:user_visit_daily_rollup, date: Date.new(2026, 4, 10))
      Fabricate(:user_visit_daily_rollup, date: Date.new(2026, 4, 15), mau: 2)

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      dau = result[:kpis].find { |k| k[:type] == :dau_mau }

      expect(dau[:value]).to be_a(Float)
    end

    describe "plugin-registered KPIs" do
      let(:kpi_entry) { { type: :extra_kpi, report: "signups", enabled: -> { @kpi_enabled } } }

      before { DiscoursePluginRegistry.stubs(:admin_dashboard_highlight_kpis).returns([kpi_entry]) }

      it "includes a registered KPI when its enabled proc returns true" do
        @kpi_enabled = true
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:kpis].map { |k| k[:type] }).to include(:extra_kpi)
      end

      it "omits a registered KPI when its enabled proc returns false" do
        @kpi_enabled = false
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:kpis].map { |k| k[:type] }).not_to include(:extra_kpi)
      end

      it "averages a registered KPI backed by an average report instead of summing it" do
        DiscoursePluginRegistry.stubs(:admin_dashboard_highlight_kpis).returns(
          [{ type: :plugin_engaged, report: "daily_engaged_users" }],
        )
        engaged_user = Fabricate(:user, created_at: Time.zone.local(2026, 1, 1))
        Fabricate(
          :user_action,
          user: engaged_user,
          action_type: UserAction::LIKE,
          created_at: Time.zone.local(2026, 4, 23, 12),
        )
        Fabricate(
          :user_action,
          user: engaged_user,
          action_type: UserAction::LIKE,
          created_at: Time.zone.local(2026, 4, 24, 12),
        )

        result = described_class.build(start_date: "2026-04-22", end_date: "2026-04-28")
        kpi = result[:kpis].find { |k| k[:type] == :plugin_engaged }

        expect(kpi[:value]).to eq(1.0) # daily average, not the two-day sum of 2
      end
    end

    it "skips a KPI when its report errors out" do
      original = Report.method(:find)
      Report.define_singleton_method(:find) do |type, *args, **kwargs|
        if type == "signups"
          r = original.call(type, *args, **kwargs)
          r.error = :timeout
          r
        else
          original.call(type, *args, **kwargs)
        end
      end

      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      expect(result[:kpis].map { |k| k[:type] }).not_to include(:new_signups)
    ensure
      Report.define_singleton_method(:find, &original)
    end

    it "falls back to a default 30-day window when params are blank" do
      result = described_class.build(start_date: nil, end_date: nil)
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "falls back to defaults when params are unparseable" do
      result = described_class.build(start_date: "garbage", end_date: "also-garbage")
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "ignores unicode garbage in date params" do
      result = described_class.build(start_date: "字字字", end_date: "字字字")
      expect(result[:kpis]).to be_an(Array)
      expect(result[:kpis]).not_to be_empty
    end

    it "does not pass current_user to Report.find so admins share one cache entry" do
      received_args = []
      original_find = Report.method(:find)
      Report.define_singleton_method(:find) do |type, opts = nil|
        received_args << (opts || {})
        original_find.call(type, opts)
      end

      described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

      expect(received_args).not_to be_empty
      received_args.each { |args| expect(args).not_to have_key(:current_user) }
    ensure
      Report.define_singleton_method(:find, &original_find)
    end

    it "parses dates in Time.zone, not UTC" do
      Time.use_zone("America/Los_Angeles") do
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-02")
        signups = result[:kpis].find { |k| k[:type] == :new_signups }
        expect(signups[:report_query][:start_date]).to eq("2026-04-01")
      end

      Time.use_zone("Etc/UTC") do
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-02")
        signups = result[:kpis].find { |k| k[:type] == :new_signups }
        expect(signups[:report_query][:start_date]).to eq("2026-04-01")
      end
    end

    it "accepts ISO8601 strings with time and drops the time-of-day" do
      result =
        described_class.build(start_date: "2026-04-01T18:00:00Z", end_date: "2026-04-28T23:59:59Z")
      signups = result[:kpis].find { |k| k[:type] == :new_signups }

      expect(signups[:report_query]).to eq(start_date: "2026-04-01", end_date: "2026-04-28")
    end

    describe "per-report caching" do
      it "reuses Report.find_cached on subsequent calls with the same date range" do
        described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

        # second call should hit the report-level cache for every core KPI
        Report.expects(:find).never

        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:kpis].map { |k| k[:type] }).to include(:new_signups, :new_contributors)
      end

      it "recomputes when the date range changes" do
        described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

        # different range — cache miss, so Report.find must be called at least once
        Report
          .expects(:find)
          .at_least_once
          .returns(stub(type: "signups", error: nil, data: [], prev_period: 0, average: false))
        Report.stubs(:cache)
        described_class.build(start_date: "2026-03-01", end_date: "2026-03-31")
      end

      it "re-evaluates plugin enabled procs on every build (no outer cache)" do
        @kpi_enabled = true
        DiscoursePluginRegistry.stubs(:admin_dashboard_highlight_kpis).returns(
          [{ type: :toggleable_kpi, report: "signups", enabled: -> { @kpi_enabled } }],
        )

        first = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(first[:kpis].map { |k| k[:type] }).to include(:toggleable_kpi)

        @kpi_enabled = false
        second = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(second[:kpis].map { |k| k[:type] }).not_to include(:toggleable_kpi)
      end
    end
  end
end
