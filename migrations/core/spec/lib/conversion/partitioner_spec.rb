# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Partitioner do
  # A stand-in for the source DB adapter, returning canned answers for the
  # primitives the partitioner calls. It has no `boundaries_by_scan`, so its scan
  # path goes through the streaming fallback.
  def build_adapter(total: 0, keys: [])
    Class
      .new do
        define_method(:count_all) { |_from, where:| total }
        define_method(:chunk_filter) { |*| "" }
        define_method(:each_partition_key) { |_key, _from, _base, &block| keys.each(&block) }
      end
      .new
  end

  def partitioner(adapter, key)
    described_class.new(adapter, key:, from: "things", base: nil)
  end

  it "samples a dense numeric key by row count, the same as any other key" do
    # No value striding: a numeric key is sampled from the sorted key too, so a
    # foreign key with many rows per value still gets even chunks.
    adapter = build_adapter(total: 100, keys: (0..99).to_a)
    expect(partitioner(adapter, :id).boundaries(4)).to eq([0, 25, 50, 75])
  end

  it "samples the sorted key for a sparse numeric key" do
    # 4 rows scattered across a million-wide range: sampling the actual ids keeps
    # the chunks even where value-sized ranges would leave most forks empty.
    adapter = build_adapter(total: 4, keys: [0, 10, 999_999, 1_000_000])
    expect(partitioner(adapter, :id).boundaries(2)).to eq([0, 999_999])
  end

  it "samples the sorted key for a non-numeric key" do
    adapter = build_adapter(total: 4, keys: %w[a b c d])
    expect(partitioner(adapter, :id).boundaries(2)).to eq(%w[a c])
  end

  it "samples a composite key without asking for numeric bounds" do
    adapter = build_adapter(total: 4, keys: [[1, 10], [1, 20], [2, 5], [3, 7]])
    expect(partitioner(adapter, %i[topic_id user_id]).boundaries(2)).to eq([[1, 10], [2, 5]])
  end

  it "is empty for an empty source" do
    expect(partitioner(build_adapter(total: 0), :id).boundaries(4)).to eq([])
  end

  it "prefers the adapter's fast scan path when it offers one" do
    # A valid PartitionSource with `boundaries_by_scan` but no `each_partition_key`,
    # so the test fails (NoMethodError) unless the partitioner takes the fast path.
    adapter =
      Class
        .new do
          define_method(:count_all) { |*, **| 0 }
          define_method(:chunk_filter) { |*| "" }
          define_method(:boundaries_by_scan) do |_key, _from, _base, count|
            [10, 20, 30].first(count)
          end
        end
        .new

    expect(partitioner(adapter, %i[a b]).boundaries(2)).to eq([10, 20])
  end

  it "raises when there is no source to compute boundaries from" do
    expect { partitioner(nil, :id).boundaries(4) }.to raise_error(
      described_class::UnsupportedSourceError,
      /doesn't implement the PartitionSource interface/,
    )
  end

  it "raises, naming the gap, when the adapter is missing a primitive" do
    adapter =
      Class
        .new do
          def chunk_filter(*)
            ""
          end
          # no count_all / each_partition_key / boundaries_by_scan
        end
        .new

    expect { partitioner(adapter, :id).boundaries(4) }.to raise_error(
      described_class::UnsupportedSourceError,
      /count_all/,
    )
  end
end
