# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Partitioner do
  # A stand-in for the source DB adapter, returning canned answers for the
  # primitives the partitioner calls. It has no `boundaries_by_scan`, so its scan
  # path goes through the streaming fallback.
  def build_adapter(min: nil, max: nil, estimate: 0, total: 0, keys: [])
    Class
      .new do
        define_method(:partition_bounds) { |_key, _from, _base| [min, max] }
        define_method(:estimated_row_count) { |_from| estimate }
        define_method(:count_all) { |_from, where:| total }
        define_method(:each_partition_key) { |_key, _from, _base, &block| keys.each(&block) }
      end
      .new
  end

  def partitioner(adapter, key)
    described_class.new(adapter, key:, from: "things", base: nil)
  end

  it "strides a dense numeric key evenly by value, without a scan" do
    adapter = build_adapter(min: 0, max: 99, estimate: 100)
    expect(partitioner(adapter, :id).boundaries(4)).to eq([0, 25, 50, 75])
  end

  it "samples the sorted key when a numeric key is too sparse for even chunks" do
    # 4 rows scattered across a million-wide range: value-sized chunks would
    # leave most forks empty, so it samples the actual ids instead
    adapter =
      build_adapter(
        min: 0,
        max: 1_000_000,
        estimate: 4,
        total: 4,
        keys: [0, 10, 999_999, 1_000_000],
      )
    expect(partitioner(adapter, :id).boundaries(2)).to eq([0, 999_999])
  end

  it "samples the sorted key for a non-numeric key" do
    adapter = build_adapter(min: "a", max: "d", total: 4, keys: %w[a b c d])
    expect(partitioner(adapter, :id).boundaries(2)).to eq(%w[a c])
  end

  it "samples a composite key without asking for numeric bounds" do
    adapter = build_adapter(total: 4, keys: [[1, 10], [1, 20], [2, 5], [3, 7]])
    expect(partitioner(adapter, %i[topic_id user_id]).boundaries(2)).to eq([[1, 10], [2, 5]])
  end

  it "is empty for an empty source" do
    expect(partitioner(build_adapter(min: nil, max: nil), :id).boundaries(4)).to eq([])
  end

  it "prefers the adapter's fast scan path when it offers one" do
    # This adapter has only `boundaries_by_scan` (no count_all / each_partition_key),
    # so the test fails unless the partitioner takes the fast path.
    adapter =
      Class
        .new do
          def boundaries_by_scan(_key, _from, _base, count)
            [10, 20, 30].first(count)
          end
        end
        .new

    expect(partitioner(adapter, %i[a b]).boundaries(2)).to eq([10, 20])
  end
end
