# frozen_string_literal: true

RSpec.describe Migrations::Importer::Customizations::Diff::TableDiff do
  let(:fake_db_class) do
    Struct.new(:rows) do
      def each_row(_schema, _table, _columns, _where, redact = nil, &block)
        rows.each { |row| block.call(redact ? redact.call(row) : row) }
      end
    end
  end

  def run_diff(key, before, after)
    described_class.new("t", %w[id name updated_at], key, %w[updated_at], nil, nil).run(
      fake_db_class.new(before),
      fake_db_class.new(after),
      "public",
    )
  end

  it "diffs keyed rows" do
    diff =
      run_diff(["id"], [%w[1 a t1], %w[2 b t1], %w[3 c t1]], [%w[1 a t1], %w[2 B t2], %w[4 d t1]])

    expect(diff.added).to eq([%w[4 d t1]])
    expect(diff.removed).to eq([%w[3 c t1]])
    expect(diff.changed).to eq(
      [
        {
          key: ["2"],
          before: %w[2 b t1],
          after: %w[2 B t2],
          diffs: {
            "name" => %w[b B],
            "updated_at" => %w[t1 t2],
          },
        },
      ],
    )
    expect(diff.same).to eq(1)
  end

  it "counts rows that only differ in ignored columns" do
    diff = run_diff(["id"], [%w[1 a t1]], [%w[1 a t2]])

    expect(diff.changed).to be_empty
    expect(diff.ignored_only).to eq(1)
  end

  it "compares rows without a key as a multiset" do
    diff = run_diff([], [%w[1 a t], %w[1 a t], %w[2 b t]], [%w[1 a t], %w[3 c t]])

    expect(diff.keyed?).to be(false)
    expect(diff.added).to eq([%w[3 c t]])
    expect(diff.removed).to contain_exactly(%w[1 a t], %w[2 b t])
    expect(diff.same).to eq(1)
  end

  it "builds row hashes" do
    diff = run_diff(["id"], [], [])
    expect(diff.row_hash(%w[1 a t])).to eq("id" => "1", "name" => "a", "updated_at" => "t")
  end
end
