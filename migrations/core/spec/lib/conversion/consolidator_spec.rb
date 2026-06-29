# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Consolidator do
  let(:shard_manager) { instance_double(Migrations::Conversion::ShardManager, discard: nil) }
  let(:intermediate_db) { class_double(Migrations::Database::IntermediateDB).as_stubbed_const }

  before { allow(intermediate_db).to receive(:merge_shard) }

  it "merges every enqueued shard in the background and discards each" do
    consolidator = described_class.new(shard_manager)
    consolidator.enqueue(%w[a.db b.db])
    consolidator.enqueue(%w[c.db])
    errors = consolidator.drain

    expect(intermediate_db).to have_received(:merge_shard).with("a.db")
    expect(intermediate_db).to have_received(:merge_shard).with("b.db")
    expect(intermediate_db).to have_received(:merge_shard).with("c.db")
    expect(shard_manager).to have_received(:discard).with("a.db")
    expect(shard_manager).to have_received(:discard).with("c.db")
    expect(errors).to be_empty
  end

  it "collects a merge error and still discards the shard" do
    boom = StandardError.new("merge boom")
    allow(intermediate_db).to receive(:merge_shard).with("bad.db").and_raise(boom)

    consolidator = described_class.new(shard_manager)
    consolidator.enqueue(%w[bad.db])
    errors = consolidator.drain

    expect(errors).to eq([boom])
    expect(shard_manager).to have_received(:discard).with("bad.db")
  end
end
