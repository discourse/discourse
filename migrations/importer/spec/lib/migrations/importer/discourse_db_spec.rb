# frozen_string_literal: true

RSpec.describe Migrations::Importer::DiscourseDB, :postgres do
  let(:database) { described_class.new(dbname: ENV.fetch("MIGRATIONS_POSTGRES_DB")) }

  after { database.close }

  it "copies rows through a managed transaction and streams the result" do
    database.query_array(
      "CREATE TEMP TABLE lifecycle_records (id bigint PRIMARY KEY, name text)",
    ).to_a
    batches = []
    database.copy_data(
      "lifecycle_records",
      %i[id name],
      [{ id: 1, name: "one" }, { id: 2, name: "two" }],
    ) { |inserted, skipped| batches << [inserted.size, skipped.size] }
    expect(batches).to eq([[2, 0]])
    expect(database.query_array("SELECT id, name FROM lifecycle_records ORDER BY id").to_a).to eq(
      [[1, "one"], [2, "two"]],
    )
  end

  it "provides column metadata and closes partially consumed streams" do
    result = database.query_result("SELECT id, id + 1 FROM generate_series(1, 3) AS rows(id)")
    expect(result.column_count).to eq(2)
    expect(result.rows.first).to eq([1, 2])
    expect(database.query_array("SELECT 42").to_a).to eq([42])
  end

  it "loads single-value and multiple-value mappings in one pass" do
    shared = Migrations::Importer::SharedData.new(database)
    expect(shared.load_mapping("SELECT id, id + 1 FROM generate_series(1, 2) AS rows(id)")).to eq(
      { 1 => 2, 2 => 3 },
    )
    expect(
      shared.load_mapping("SELECT id, id + 1, id + 2 FROM generate_series(1, 2) AS rows(id)"),
    ).to eq({ 1 => [2, 3], 2 => [3, 4] })
  end

  it "protects the importer's parent session across a worker fork" do
    backend_pid = database.query_array("SELECT pg_backend_pid()").first
    expect(
      in_migration_worker do
        GC.start
        begin
          database.query_array("SELECT 1").to_a
        rescue Migrations::Database::ManagedConnection::DiscardedError
          :discarded
        end
      end,
    ).to eq(:discarded)
    expect(database.query_array("SELECT pg_backend_pid()").first).to eq(backend_pid)
  end
end
