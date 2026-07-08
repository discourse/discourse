# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::Discourse::Posts do
  subject(:processor) { described_class.processor_class.new({}) }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  def rows(table)
    [].tap { |out| @db.query("SELECT * FROM #{table}") { |row| out << row } }
  end

  def post_item(raw, id: 1)
    { id:, topic_id: 10, post_number: id, raw:, created_at: Time.utc(2020, 1, 2, 3, 4, 5) }
  end

  describe "the foreign-host internal-link signal" do
    before do
      processor.internal_link_hosts = Set["forum.example.com"]
      processor.setup
    end

    it "tallies foreign-host links per host instead of logging on the scan path" do
      processor.process(post_item("see https://old-forum.example.com/t/slug/99 here", id: 1))
      processor.process(post_item("also https://old-forum.example.com/t/other/7 there", id: 2))

      # Nothing is written or counted during the scan; the tally rides back via
      # `result` for the parent's reducer.
      expect(rows("log_entries")).to be_empty
      expect(processor.tracker.stats.warning_count).to eq(0)
      expect(processor.tracker.stats.error_count).to eq(0)
      expect(processor.result).to eq({ "old-forum.example.com" => 2 })
    end

    it "hands back nil when no foreign-host link was seen" do
      processor.process(post_item("read https://forum.example.com/t/slug/99 now"))

      expect(rows("log_entries")).to be_empty
      expect(processor.result).to be_nil
    end
  end

  describe ".combine_results" do
    it "sums each worker's per-host tally and writes one WARNING per host" do
      count =
        described_class.combine_results(
          [
            { "old-forum.example.com" => 3, "legacy.example.com" => 1 },
            { "old-forum.example.com" => 2 },
          ],
        )

      expect(count).to eq(2) # distinct hosts, the step's added warning count

      entries = rows("log_entries")
      expect(entries.size).to eq(2)
      expect(entries).to all(
        include(
          type: Migrations::Database::IntermediateDB::LogEntry::WARNING,
          message: described_class::FOREIGN_LINK_LOG_MESSAGE,
        ),
      )

      by_host = entries.index_by { |entry| JSON.parse(entry[:details])["host"] }
      expect(JSON.parse(by_host["old-forum.example.com"][:details])["count"]).to eq(5)
      expect(JSON.parse(by_host["legacy.example.com"][:details])["count"]).to eq(1)
    end

    it "writes nothing and reports zero hosts for no results" do
      expect(described_class.combine_results([])).to eq(0)
      expect(rows("log_entries")).to be_empty
    end
  end
end
