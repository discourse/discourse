# frozen_string_literal: true

RSpec.describe MethodProfiler do
  class Sneetch
    def beach
    end

    def recurse(count = 5)
      recurse(count - 1) if count > 0
    end
  end

  it "can bypass recursion on demand" do
    MethodProfiler.patch(Sneetch, [:recurse], :recurse, no_recurse: true)

    MethodProfiler.start
    Sneetch.new.recurse
    result = MethodProfiler.stop

    expect(result[:recurse][:calls]).to eq(1)
  end

  it "can transfer data between threads" do
    MethodProfiler.patch(Sneetch, [:beach], :at_beach)

    MethodProfiler.start
    Sneetch.new.beach
    data = MethodProfiler.transfer
    result = nil
    Thread
      .new do
        MethodProfiler.start(data)
        Sneetch.new.beach
        result = MethodProfiler.stop
      end
      .join

    expect(result[:at_beach][:calls]).to eq(2)
  end

  describe ".stop" do
    before { MethodProfiler.ensure_discourse_instrumentation! }

    after { MethodProfiler.itemize_enabled = false }

    context "when itemize_enabled is true" do
      before { MethodProfiler.itemize_enabled = true }

      it "records each sql statement and redis command in order" do
        MethodProfiler.start

        ActiveRecord::Base.connection.execute("SELECT 1")
        ActiveRecord::Base.connection.execute("SELECT 1")
        Discourse.redis.get("method_profiler_itemize_test")

        result = MethodProfiler.stop

        expect(result[:sql]).to match(
          calls: 2,
          duration: a_kind_of(Float),
          items: [
            { sql: a_string_starting_with("SELECT 1"), duration_ms: a_kind_of(Numeric) },
            { sql: a_string_starting_with("SELECT 1"), duration_ms: a_kind_of(Numeric) },
          ],
        )

        expect(result[:redis]).to match(
          calls: 1,
          duration: a_kind_of(Float),
          items: [
            {
              command: "GET #{Discourse.redis.namespace_key("method_profiler_itemize_test")}",
              duration_ms: a_kind_of(Numeric),
            },
          ],
        )
      end

      it "scrubs invalid utf-8 bytes so itemized commands stay json-safe" do
        MethodProfiler.start

        Discourse.redis.set("method_profiler_binary_test", "\xC2".b)

        result = MethodProfiler.stop

        item =
          result[:redis][:items].find do |entry|
            entry[:command].include?("method_profiler_binary_test")
          end
        expect(item[:command]).to be_valid_encoding
        expect { JSON.generate(item) }.not_to raise_error
      end

      it "truncates very long itemized values so the output stays bounded" do
        MethodProfiler.start

        Discourse.redis.set("method_profiler_long_test", "x" * 5000)

        result = MethodProfiler.stop

        item =
          result[:redis][:items].find do |entry|
            entry[:command].include?("method_profiler_long_test")
          end
        expect(item[:command].length).to be <= 2100
        expect(item[:command]).to include("(truncated")
      end
    end

    context "when itemize_enabled is false" do
      it "records only counts and duration, with no items" do
        MethodProfiler.start

        ActiveRecord::Base.connection.execute("SELECT 1")

        result = MethodProfiler.stop

        expect(result[:sql]).to match(calls: a_kind_of(Integer), duration: a_kind_of(Float))
      end
    end
  end
end
