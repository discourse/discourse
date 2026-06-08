# frozen_string_literal: true

RSpec.describe Discourse::PerformanceFormatter::RequestGroup do
  let(:timing) do
    {
      sql: {
        calls: 2,
        duration: 0.004,
        items: [{ sql: "SELECT 1", duration_ms: 0.2 }, { sql: "SELECT 1", duration_ms: 0.2 }],
      },
      redis: {
        calls: 1,
        duration: 0.001,
        items: [{ command: "GET foo", duration_ms: 0.05 }],
      },
      total_duration: 0.01,
    }
  end

  let(:env) { { "REQUEST_METHOD" => "GET", "PATH_INFO" => "/t/123.json" } }

  describe ".build" do
    it "builds a group with method, path, status and itemized calls derived from the timing" do
      group = described_class.build(env, { status: 200, is_background: false, timing: timing })

      expect(group).to eq(
        method: "GET",
        path: "/t/123.json",
        status: 200,
        totals: {
          sql: {
            calls: 2,
            duration_ms: 0.4,
          },
          redis: {
            calls: 1,
            duration_ms: 0.05,
          },
          net: {
            calls: 0,
            duration_ms: 0.0,
          },
        },
        sql: timing[:sql][:items],
        redis: timing[:redis][:items],
        net: [],
      )
    end

    context "when the request is a background request" do
      it "returns nil so message-bus polling does not pollute output" do
        group = described_class.build(env, { status: 200, is_background: true, timing: timing })

        expect(group).to be_nil
      end
    end

    context "when the request timing is missing (failed request)" do
      it "returns a zeroed group with empty arrays" do
        group = described_class.build(env, { status: 500, is_background: false, timing: nil })

        expect(group).to eq(
          method: "GET",
          path: "/t/123.json",
          status: 500,
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
