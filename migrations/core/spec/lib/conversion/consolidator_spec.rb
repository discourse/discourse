# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Consolidator do
  let(:shard_manager) { instance_double(Migrations::Conversion::ShardManager, discard: nil) }
  let(:writer) { instance_double(Migrations::Database::DbWriter, merge_shard: nil) }

  it "merges every enqueued shard through the writer in the background and discards each" do
    consolidator = described_class.new(shard_manager, writer)
    consolidator.enqueue(%w[a.db b.db])
    consolidator.enqueue(%w[c.db])
    errors = consolidator.drain

    expect(writer).to have_received(:merge_shard).with("a.db")
    expect(writer).to have_received(:merge_shard).with("b.db")
    expect(writer).to have_received(:merge_shard).with("c.db")
    expect(shard_manager).to have_received(:discard).with("a.db")
    expect(shard_manager).to have_received(:discard).with("c.db")
    expect(errors).to be_empty
  end

  it "collects a merge error and still discards the shard" do
    boom = StandardError.new("merge boom")
    allow(writer).to receive(:merge_shard).with("bad.db").and_raise(boom)

    consolidator = described_class.new(shard_manager, writer)
    consolidator.enqueue(%w[bad.db])
    errors = consolidator.drain

    expect(errors).to eq([boom])
    expect(shard_manager).to have_received(:discard).with("bad.db")
  end
end
