# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::Discourse::Posts do
  subject(:processor) { described_class.processor_class.new({}) }

  def enums
    Migrations::Database::IntermediateDB::Enums
  end

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

  describe "converting a post" do
    before do
      processor.internal_link_hosts = Set["forum.example.com"]
      processor.setup
    end

    it "writes the post row and the deferred embed linkage" do
      raw = "Welcome @alice, glad you joined!"
      processor.process(
        post_item(raw, id: 42).merge(locale: "de", post_type: enums::PostType::REGULAR),
      )

      post = rows("posts").first
      expect(post).to include(
        original_id: 42,
        topic_id: 10,
        post_number: 42,
        locale: "de",
        original_raw: raw,
      )
      # The mention is deferred, so the stored raw carries a placeholder token
      # in place of the input body's mention.
      expect(Migrations::Placeholder).to be_include(post[:raw])

      mention = rows("embed_mentions").first
      expect(mention).to include(owner_id: 42, name: "alice")
    end

    it "falls back on unknown enum values and passes known ones through" do
      processor.process(post_item("first", id: 1).merge(post_type: 999, hidden_reason_id: 999))
      processor.process(post_item("second", id: 2).merge(post_type: enums::PostType::WHISPER))

      by_id = rows("posts").index_by { |row| row[:original_id] }
      expect(by_id[1][:post_type]).to eq(enums::PostType::REGULAR)
      expect(by_id[1][:hidden_reason_id]).to be_nil
      expect(by_id[2][:post_type]).to eq(enums::PostType::WHISPER)
    end
  end

  describe ".combine_results" do
    let(:tracker) { Migrations::Conversion::StepTracker.new }

    def entry
      entries = rows("log_entries")
      expect(entries.size).to eq(1)
      entries.first
    end

    def hosts_in(details)
      JSON.parse(details)["hosts"].map { |row| [row["host"], row["count"]] }
    end

    it "merges the workers' tallies into one INFO entry, hosts sorted by count" do
      described_class.combine_results(
        [
          { "old-forum.example.com" => 3, "legacy.example.com" => 1 },
          { "old-forum.example.com" => 2, "another.example.com" => 4 },
        ],
        tracker,
      )

      expect(tracker.stats.warning_count).to eq(0) # no dominant host, nothing to warn about
      expect(entry).to include(
        type: Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: described_class::FOREIGN_LINK_LOG_MESSAGE,
      )
      expect(JSON.parse(entry[:details])["total"]).to eq(10)
      expect(hosts_in(entry[:details])).to eq(
        [["old-forum.example.com", 5], ["another.example.com", 4], ["legacy.example.com", 1]],
      )
      expect(JSON.parse(entry[:details])).not_to have_key("omitted")
    end

    it "caps the host list and records how many hosts it dropped" do
      # One more host than the cap, each with a distinct count so the order is
      # deterministic and the smallest one is the host that gets dropped.
      tally = {}
      501.times { |i| tally["host#{i}.example"] = i + 1 }

      described_class.combine_results([tally], tracker)

      details = JSON.parse(entry[:details])
      expect(details["hosts"].size).to eq(500)
      expect(details["omitted"]).to eq(1)
      # `total` still sums every host, dropped ones included.
      expect(details["total"]).to eq((1..501).sum)
      # The busiest host stays at the head of the kept list.
      expect(hosts_in(entry[:details]).first).to eq(["host500.example", 501])
    end

    it "logs a WARNING through the tracker when a host dominates the list" do
      described_class.combine_results(
        [{ "old-forum.example.com" => 300 }, { "other.example.com" => 50, "misc.example" => 40 }],
        tracker,
      )

      expect(tracker.stats.warning_count).to eq(1)
      expect(entry).to include(type: Migrations::Database::IntermediateDB::LogEntry::WARNING)
      expect(hosts_in(entry[:details]).first).to eq(["old-forum.example.com", 300])
    end

    it "does not let a small forum's handful of links dominate" do
      # 3 of 4 links is 75%, but far below the absolute minimum a former domain
      # would accumulate.
      described_class.combine_results([{ "old.example" => 3, "other.example" => 1 }], tracker)

      expect(tracker.stats.warning_count).to eq(0)
      expect(entry).to include(type: Migrations::Database::IntermediateDB::LogEntry::INFO)
    end

    it "writes nothing for no results" do
      described_class.combine_results([], tracker)

      expect(tracker.stats.warning_count).to eq(0)
      expect(rows("log_entries")).to be_empty
    end
  end
end
