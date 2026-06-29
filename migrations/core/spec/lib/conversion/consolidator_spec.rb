# frozen_string_literal: true

RSpec.describe Migrations::Conversion::Consolidator do
  let(:shard_manager) { instance_double(Migrations::Conversion::ShardManager, discard: nil) }
  let(:connection) do
    instance_double(
      Migrations::Database::Connection,
      merge_database: nil,
      tables: %w[topics config schema_migrations],
    )
  end
  let(:fork_mutex) { Mutex.new }

  it "merges every enqueued shard into the run connection and discards each" do
    consolidator = described_class.new(shard_manager, connection, fork_mutex)
    consolidator.enqueue(%w[a.db b.db])
    consolidator.enqueue(%w[c.db])
    errors = consolidator.drain

    # `config` and `schema_migrations` are excluded from the merge
    expect(connection).to have_received(:merge_database).with("a.db", tables: %w[topics])
    expect(connection).to have_received(:merge_database).with("b.db", tables: %w[topics])
    expect(connection).to have_received(:merge_database).with("c.db", tables: %w[topics])
    expect(shard_manager).to have_received(:discard).with("a.db")
    expect(shard_manager).to have_received(:discard).with("c.db")
    expect(errors).to be_empty
  end

  it "collects a merge error and still discards the shard" do
    boom = StandardError.new("merge boom")
    allow(connection).to receive(:merge_database).with("bad.db", tables: anything).and_raise(boom)

    consolidator = described_class.new(shard_manager, connection, fork_mutex)
    consolidator.enqueue(%w[bad.db])
    errors = consolidator.drain

    expect(errors).to eq([boom])
    expect(shard_manager).to have_received(:discard).with("bad.db")
  end
end
