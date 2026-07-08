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

  def post_item(raw)
    { id: 1, topic_id: 10, post_number: 1, raw:, created_at: Time.utc(2020, 1, 2, 3, 4, 5) }
  end

  describe "the foreign-host internal-link signal" do
    before do
      processor.internal_link_hosts = Set["forum.example.com"]
      processor.setup
    end

    it "logs an INFO entry per foreign-host self-link, with the host in details" do
      processor.process(post_item("see https://old-forum.example.com/t/slug/99 here"))

      entries = rows("log_entries")
      expect(entries.size).to eq(1)
      expect(entries.first).to include(
        type: Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: described_class::FOREIGN_LINK_LOG_MESSAGE,
      )
      expect(entries.first[:details]).to include("old-forum.example.com")
    end

    it "does not inflate the step's warning or error counts" do
      processor.tracker.reset_stats!
      processor.process(post_item("read https://old-forum.example.com/t/slug/99 now"))

      expect(processor.tracker.stats.warning_count).to eq(0)
      expect(processor.tracker.stats.error_count).to eq(0)
    end

    it "logs nothing for a link on a configured host" do
      processor.process(post_item("read https://forum.example.com/t/slug/99 now"))

      expect(rows("log_entries")).to be_empty
    end
  end
end
