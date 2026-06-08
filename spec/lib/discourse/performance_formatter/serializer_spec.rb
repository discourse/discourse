# frozen_string_literal: true

require "ostruct"

RSpec.describe Discourse::PerformanceFormatter::Serializer do
  def build_example(status: :passed, exception: nil)
    OpenStruct.new(
      location_rerun_argument: "./spec/foo_spec.rb:12",
      full_description: "Foo does a thing",
      location: "./spec/foo_spec.rb:12",
      execution_result: OpenStruct.new(status: status, exception: exception),
    )
  end

  let(:perf) do
    {
      totals: {
        sql: {
          calls: 1,
          duration_ms: 0.4,
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
      sql: [{ sql: "SELECT 1", duration_ms: 0.4 }],
      redis: [],
      net: [],
      requests: [],
    }
  end

  describe ".serialize" do
    it "produces an object with the example identity, status and perf payload" do
      result = described_class.serialize(build_example, perf)

      expect(result).to eq(
        example_id: "./spec/foo_spec.rb:12",
        description: "Foo does a thing",
        location: "./spec/foo_spec.rb:12",
        status: "passed",
        totals: {
          sql: {
            calls: 1,
            duration_ms: 0.4,
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
        sql: [{ sql: "SELECT 1", duration_ms: 0.4 }],
        redis: [],
        net: [],
        requests: [],
      )
    end

    it "produces identical output whether perf is symbol-keyed or round-tripped through json" do
      round_tripped = JSON.parse(JSON.generate(perf))

      from_symbols = described_class.serialize(build_example, perf)
      from_json = described_class.serialize(build_example, round_tripped)

      expect(from_json).to eq(from_symbols)
    end

    context "when the example failed" do
      it "includes the error class, message and backtrace" do
        exception =
          begin
            raise StandardError, "boom"
          rescue StandardError => error
            error
          end

        result = described_class.serialize(build_example(status: :failed, exception:), perf)

        expect(result[:status]).to eq("failed")
        expect(result[:error]).to match(
          class: "StandardError",
          message: "boom",
          backtrace: a_kind_of(Array),
        )
      end
    end

    context "when the example has no captured perf data" do
      it "emits a valid line with empty perf" do
        result = described_class.serialize(build_example(status: :pending), nil)

        expect(result).to eq(
          example_id: "./spec/foo_spec.rb:12",
          description: "Foo does a thing",
          location: "./spec/foo_spec.rb:12",
          status: "pending",
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
          requests: [],
        )
      end
    end
  end
end
