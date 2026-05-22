# frozen_string_literal: true

describe AdminDashboardEngagement do
  describe ".build" do
    before do
      freeze_time(Time.zone.local(2026, 4, 28, 12, 0, 0))
      Discourse.cache.clear
    end

    it "returns a kpis array keyed by report type" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")

      expect(result[:kpis]).to be_an(Array)
      types = result[:kpis].map { |k| k[:type] }
      expect(types).to include(:dau_mau, :daily_engaged_users, :new_signups)
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

    it "emits report_type and report_query for drill-down" do
      result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
      engaged = result[:kpis].find { |k| k[:type] == :daily_engaged_users }

      expect(engaged[:report_type]).to eq("daily_engaged_users")
      expect(engaged[:report_query]).to eq(start_date: "2026-04-01", end_date: "2026-04-28")
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

    describe "headline" do
      def stub_kpis(signups:, dau: 0, engaged: 0)
        described_class
          .any_instance
          .stubs(:build_kpis)
          .returns(
            [
              { type: :dau_mau, percent_change: dau },
              { type: :new_signups, percent_change: signups },
              { type: :daily_engaged_users, percent_change: engaged },
            ],
          )
      end

      it "returns healthy_growth when every metric is non-negative and at least one is positive" do
        stub_kpis(signups: 12, dau: 3, engaged: 5)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("healthy_growth")
      end

      it "returns declining when every metric is non-positive and at least one is negative" do
        stub_kpis(signups: -8, dau: -2, engaged: -5)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("declining")
      end

      it "returns engaged_but_shrinking when stickiness is up but engagement or signups fell" do
        stub_kpis(signups: -5, dau: 2, engaged: -3)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("engaged_but_shrinking")
      end

      it "returns growing_but_distracted when sign-ups rose but stickiness slipped" do
        stub_kpis(signups: 10, dau: -4, engaged: 0)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("growing_but_distracted")
      end

      it "returns no_signal when every metric has no change" do
        stub_kpis(signups: 0, dau: 0, engaged: 0)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("no_signal")
      end

      it "returns mixed when stickiness fell, sign-ups flat, but engagement rose" do
        stub_kpis(signups: 0, dau: -3, engaged: 4)
        result = described_class.build(start_date: "2026-04-01", end_date: "2026-04-28")
        expect(result[:headline][:key]).to end_with("mixed")
      end
    end
  end
end
