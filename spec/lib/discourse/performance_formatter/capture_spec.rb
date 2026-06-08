# frozen_string_literal: true

RSpec.describe Discourse::PerformanceFormatter::Capture do
  before do
    MethodProfiler.ensure_discourse_instrumentation!
    MethodProfiler.itemize_enabled = true
  end

  after { MethodProfiler.itemize_enabled = false }

  describe ".measure" do
    it "captures itemized sql, redis and net calls, preserving order and duplicates" do
      stub_request(:get, "https://perf.example.com/ping").to_return(status: 200, body: "ok")

      result =
        described_class.measure do
          ActiveRecord::Base.connection.execute("SELECT 1")
          ActiveRecord::Base.connection.execute("SELECT 1")
          Discourse.redis.get("perf_capture_key_a")
          Discourse.redis.get("perf_capture_key_b")
          Net::HTTP.get(URI("https://perf.example.com/ping"))
        end

      expect(result).to match(
        totals: {
          sql: {
            calls: 2,
            duration_ms: a_kind_of(Numeric),
          },
          redis: {
            calls: 2,
            duration_ms: a_kind_of(Numeric),
          },
          net: {
            calls: 1,
            duration_ms: a_kind_of(Numeric),
          },
        },
        sql: [
          { sql: a_string_starting_with("SELECT 1"), duration_ms: a_kind_of(Numeric) },
          { sql: a_string_starting_with("SELECT 1"), duration_ms: a_kind_of(Numeric) },
        ],
        redis: [
          {
            command: "GET #{Discourse.redis.namespace_key("perf_capture_key_a")}",
            duration_ms: a_kind_of(Numeric),
          },
          {
            command: "GET #{Discourse.redis.namespace_key("perf_capture_key_b")}",
            duration_ms: a_kind_of(Numeric),
          },
        ],
        net: [
          { method: "GET", url: "https://perf.example.com/ping", duration_ms: a_kind_of(Numeric) },
        ],
      )
    end

    context "when the block performs no instrumented work" do
      it "returns empty groups and zeroed totals" do
        result = described_class.measure { 1 + 1 }

        expect(result).to eq(
          totals: {
            sql: {
              calls: 0,
              duration_ms: 0.0,
            },
            redis: {
              calls: 0,
              duration_ms: 0.0,
            },
            net: {
              calls: 0,
              duration_ms: 0.0,
            },
          },
          sql: [],
          redis: [],
          net: [],
        )
      end
    end
  end
end
