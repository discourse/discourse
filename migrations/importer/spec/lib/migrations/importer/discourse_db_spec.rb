# frozen_string_literal: true

RSpec.describe Migrations::Importer::DiscourseDB, :rails do
  subject(:db) { described_class.new }

  after { db.close }

  it "configures the session for imports" do
    expect(db.query_array("SHOW TimeZone").first).to eq("UTC")
    expect(db.query_array("SHOW statement_timeout").first).to eq("0")
    expect(db.query_array("SHOW idle_in_transaction_session_timeout").first).to eq("0")
    expect(db.query_array("SHOW application_name").first).to eq("discourse-migrations-importer")
  end

  it "drains abandoned result streams so the connection stays usable" do
    expect(db.query_result("SELECT generate_series(1, 10000)").rows.first).to eq(1)
    expect(db.query_array("SELECT 42").first).to eq(42)
  end

  it "materializes query arrays" do
    rows = db.query_array("SELECT generate_series(1, 3)")

    expect(rows).to eq([1, 2, 3])
  end

  it "refuses to consume a result stream twice" do
    rows = db.query_result("SELECT 1").rows
    rows.to_a

    expect { rows.to_a }.to raise_error(RuntimeError, /consumed once/)
  end

  it "stores NOW() timestamps in UTC" do
    db.query_array("CREATE TEMP TABLE _db_spec_now (id int NOT NULL, created_at timestamp)")
    db.copy_data("_db_spec_now", %i[id created_at], [{ id: 1, created_at: "NOW()" }]) { |_i, _s| }

    stored = db.query_array("SELECT created_at::text FROM _db_spec_now").first
    expect(Time.parse("#{stored} UTC")).to be_within(60).of(Time.now.utc)
  end

  it "wraps COPY errors with the table and row range" do
    db.query_array("CREATE TEMP TABLE _db_spec_err (id int NOT NULL)")

    expect {
      db.copy_data("_db_spec_err", %i[id], [{ id: 1 }, { id: nil }]) { |_i, _s| }
    }.to raise_error(PG::NotNullViolation, /table _db_spec_err, rows 1-2 of this step/)
  end

  it "quarantines failing rows and inserts the rest" do
    db.query_array("CREATE TEMP TABLE _db_spec_quarantine (id int NOT NULL)")
    failed = []
    rows = [{ id: 1 }, { id: nil }, { id: 3 }, { id: nil }, { id: 5 }]

    db.copy_data(
      "_db_spec_quarantine",
      %i[id],
      rows,
      on_failed_row: ->(row, error) { failed << [row, error] },
    ) { |_i, _s| }

    expect(db.query_array("SELECT id FROM _db_spec_quarantine ORDER BY id")).to eq([1, 3, 5])
    expect(failed.map(&:first)).to eq([{ id: nil }, { id: nil }])
    expect(failed.map(&:last)).to all(be_a(PG::NotNullViolation))
  end

  it "still hands marker-skipped rows to the commit callback when their sub-batch fails" do
    db.query_array("CREATE TEMP TABLE _db_spec_markers (id int NOT NULL)")
    skipped_seen = []
    marker = described_class::SKIP_ROW_MARKER
    rows = [{ id: 1 }, { id: nil }, { marker => true, :id => 7 }]

    db.copy_data(
      "_db_spec_markers",
      %i[id],
      rows,
      on_failed_row: ->(_row, _error) {},
    ) { |_inserted, skipped| skipped_seen.concat(skipped) }

    expect(skipped_seen).to eq([{ marker => true, :id => 7 }])
    expect(db.query_array("SELECT id FROM _db_spec_markers")).to eq([1])
  end

  it "aborts when every row of a batch fails" do
    db.query_array("CREATE TEMP TABLE _db_spec_systemic (id int NOT NULL)")

    expect {
      db.copy_data(
        "_db_spec_systemic",
        %i[id],
        [{ id: nil }, { id: nil }],
        on_failed_row: ->(_row, _error) { raise "not reached" },
      ) { |_i, _s| }
    }.to raise_error(PG::NotNullViolation, /all 2 rows of a batch failed to insert/)
  end

  it "gives up when too many rows of a batch fail" do
    db.query_array("CREATE TEMP TABLE _db_spec_cap (id int NOT NULL)")
    quarantined = 0
    rows = 1.upto(36).map { |id| { id: (id % 3).zero? ? nil : id } } # 12 bad of 36, limit is 10

    expect {
      db.copy_data(
        "_db_spec_cap",
        %i[id],
        rows,
        on_failed_row: ->(_row, _error) { quarantined += 1 },
      ) { |_i, _s| }
    }.to raise_error(
      PG::NotNullViolation,
      /too many rows of a batch failed to insert, giving up after 11/,
    )

    expect(quarantined).to eq(0)
  end

  it "returns column names in table order" do
    names = db.column_names("badges")

    expect(names.first).to eq(:id)
    expect(names).to include(:name, :badge_type_id)
  end

  it "fails fast for unknown tables" do
    expect { db.column_names("no_such_table") }.to raise_error(PG::UndefinedTable)
  end
end
