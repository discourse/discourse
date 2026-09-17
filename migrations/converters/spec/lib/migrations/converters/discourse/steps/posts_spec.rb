# frozen_string_literal: true

require "tmpdir"

RSpec.describe Migrations::Converters::Discourse::Posts do
  subject(:processor) { described_class.processor_class.new({}) }

  let(:enums) { Migrations::Database::IntermediateDB::Enums }

  # The names the fake source has. The engine and the extractor must agree on
  # them; the converter's `step_args` does that, here the engine config
  # supplies both sides.
  let(:hashtag_name_list) { %w[support] }

  let(:markdown_engine) { MarkdownEngineHelper.context_for_names(hashtag_names: hashtag_name_list) }

  let(:mention_names) do
    Migrations::CompactStringSet.new(
      %w[alice bob].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
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

  # A V8 isolate per example costs ~70ms and ~33 MiB, so the examples share
  # the suite's context.
  before do
    allow(Migrations::Converters::MarkdownEngine::Context).to receive(:new).and_return(
      markdown_engine,
    )

    processor.markdown_bundle = MarkdownEngineHelper.bundle
    processor.markdown_config = markdown_engine.config
    processor.mention_names = mention_names
    processor.hashtag_names = markdown_engine.config.hashtag_names
    processor.internal_link_hosts = { "forum.example.com" => nil }
  end

  def rows(table)
    [].tap { |out| @db.query("SELECT * FROM #{table}") { |row| out << row } }
  end

  def post_item(raw, id: 1, **overrides)
    {
      id:,
      topic_id: 10,
      post_number: id,
      raw:,
      created_at: Time.utc(2020, 1, 2, 3, 4, 5),
      **overrides,
    }
  end

  describe "#setup" do
    it "builds the engine in the worker, out of the bundle the parent loaded" do
      processor.setup

      expect(Migrations::Converters::MarkdownEngine::Context).to have_received(:new).with(
        bundle: MarkdownEngineHelper.bundle,
        config: markdown_engine.config,
      )
    end
  end

  describe "#process_batch" do
    before { processor.setup }

    it "converts a batch of bodies and links their embeds to each post" do
      processor.process_batch(
        [
          post_item("Welcome @alice, glad you joined!", id: 42, locale: "de"),
          post_item("Have a look at #support", id: 43),
          post_item("Nothing to extract here.", id: 44),
        ],
      )

      posts = rows("posts").index_by { |row| row[:original_id] }
      expect(posts.keys).to contain_exactly(42, 43, 44)

      expect(posts[42]).to include(
        topic_id: 10,
        post_number: 42,
        locale: "de",
        original_raw: "Welcome @alice, glad you joined!",
      )
      # Deferred embeds leave a placeholder in the stored raw; a body without
      # embeds is stored as is.
      expect(Migrations::Placeholder).to be_include(posts[42][:raw])
      expect(Migrations::Placeholder).to be_include(posts[43][:raw])
      expect(posts[44][:raw]).to eq("Nothing to extract here.")

      expect(rows("embed_mentions")).to contain_exactly(
        hash_including(owner_id: 42, owner_type: enums::EmbedOwner::POST, name: "alice"),
      )
      expect(rows("embed_hashtags")).to contain_exactly(
        hash_including(owner_id: 43, owner_type: enums::EmbedOwner::POST, name: "support"),
      )
    end

    it "scans the batch's engine-bound bodies in one call, skipping the rest" do
      scanned = []
      allow(markdown_engine).to receive(:scan).and_wrap_original do |original, posts, **options|
        scanned << posts.map { |post| post[:id] }
        original.call(posts, **options)
      end

      processor.process_batch(
        [
          post_item("Welcome @alice", id: 1),
          post_item("Nothing to extract here.", id: 2),
          post_item("Hello @bob", id: 3),
        ],
      )

      expect(scanned).to eq([[1, 3]])
    end

    it "stores an empty body as it came in, with nothing deferred for it" do
      processor.process_batch([post_item("", id: 2)])

      expect(rows("posts").first).to include(original_id: 2, raw: "", original_raw: "")
      expect(rows("embed_mentions")).to be_empty
    end

    it "reports a post without a body instead of writing a row the column rejects" do
      processor.process_batch([post_item(nil, id: 1), post_item("second", id: 2)])

      expect(rows("posts").map { |row| row[:original_id] }).to eq([2])
      expect(processor.tracker.stats.error_count).to eq(1)
      expect(JSON.parse(rows("log_entries").first[:details])).to eq("id" => 1)
    end

    it "keeps one post's embeds out of the next one's" do
      processor.process_batch([post_item("Hello @alice", id: 1), post_item("Nothing here", id: 2)])

      expect(rows("embed_mentions").map { |row| row[:owner_id] }).to eq([1])
    end

    it "falls back on unknown enum values and passes known ones through" do
      processor.process_batch(
        [
          post_item("first", id: 1, post_type: 999, hidden_reason_id: 999),
          post_item("second", id: 2, post_type: enums::PostType::WHISPER),
        ],
      )

      posts = rows("posts").index_by { |row| row[:original_id] }
      expect(posts[1][:post_type]).to eq(enums::PostType::REGULAR)
      expect(posts[1][:hidden_reason_id]).to be_nil
      expect(posts[2][:post_type]).to eq(enums::PostType::WHISPER)
    end

    it "loses only the post that fails, not the rest of the batch" do
      allow(Migrations::Database::IntermediateDB::Post).to receive(:create).and_call_original
      allow(Migrations::Database::IntermediateDB::Post).to receive(:create).with(
        hash_including(original_id: 1),
      ).and_raise("boom")

      processor.process_batch([post_item("first", id: 1), post_item("second", id: 2)])

      expect(rows("posts").map { |row| row[:original_id] }).to eq([2])
      expect(processor.tracker.stats.error_count).to eq(1)

      entry = rows("log_entries").first
      expect(entry[:message]).to eq("Failed to process post")
      expect(JSON.parse(entry[:details])).to eq("id" => 1)
    end
  end

  describe "engine reports" do
    before { processor.setup }

    it "names the post an engine refusal belongs to" do
      refuse_on(processor, :count_mismatch, "detail")

      processor.process_batch([post_item("Hello @alice", id: 7)])

      expect(processor.tracker.stats.warning_count).to eq(1)
      entry = rows("log_entries").first
      expect(entry[:message]).to eq(described_class::ENGINE_REFUSAL_LOG_MESSAGE)
      expect(JSON.parse(entry[:details])).to eq(
        "id" => 7,
        "cause" => "count_mismatch",
        "detail" => "detail",
      )
    end

    it "records a slow parse at INFO without counting it as a warning" do
      report_slow_parse(processor)

      processor.process_batch([post_item("Hello @alice", id: 8)])

      expect(processor.tracker.stats.warning_count).to eq(0)
      entry = rows("log_entries").first
      expect(entry[:message]).to eq(described_class::SLOW_PARSE_LOG_MESSAGE)
      expect(JSON.parse(entry[:details])).to eq("id" => 8)
    end

    # The extractor decides when to report. The step only attaches the post id,
    # so the reports are triggered through the callbacks directly.
    def refuse_on(processor, cause, detail)
      callback = extractor_option(processor, :@on_engine_refusal)
      allow_extraction(processor) { callback.call(cause, detail) }
    end

    def report_slow_parse(processor)
      callback = extractor_option(processor, :@on_slow_parse)
      allow_extraction(processor) { callback.call }
    end

    def extractor_option(processor, name)
      processor.instance_variable_get(:@extractor).instance_variable_get(name)
    end

    def allow_extraction(processor, &report)
      extractor = processor.instance_variable_get(:@extractor)
      allow(extractor).to receive(:extract_prepared) do |prepared, **|
        report.call
        prepared.raw
      end
    end
  end

  describe "the foreign-host internal-link signal" do
    before { processor.setup }

    it "collects the foreign hosts instead of logging on the scan path" do
      processor.process_batch(
        [
          post_item("see https://old-forum.example.com/t/slug/99 here", id: 1),
          post_item("also https://legacy.example.com/t/other/7 there", id: 2),
          post_item("and https://old-forum.example.com/t/more/8 again", id: 3),
        ],
      )

      # Nothing is logged during the scan; the list goes to the parent via
      # `result`.
      expect(rows("log_entries")).to be_empty
      expect(processor.tracker.stats.warning_count).to eq(0)
      expect(processor.tracker.stats.error_count).to eq(0)
      expect(processor.result).to eq(%w[legacy.example.com old-forum.example.com])
    end

    it "hands back nil when no foreign-host link was seen" do
      processor.process_batch([post_item("read https://forum.example.com/t/slug/99 now")])

      expect(rows("log_entries")).to be_empty
      expect(processor.result).to be_nil
    end
  end

  describe "a subfolder install (host prefix and base prefix)" do
    before do
      processor.internal_link_hosts = { "forum.example.com" => "/forum" }
      processor.internal_link_base_prefix = "/forum"
      processor.setup
    end

    it "defers a relative link written with the site's own prefix" do
      processor.process_batch([post_item("see [here](/forum/t/slug/99) please")])

      link = rows("embed_links").first
      expect(link).to include(owner_id: 1, url: "/forum/t/slug/99")
    end

    it "defers an absolute link inside the host's prefix" do
      processor.process_batch([post_item("see https://forum.example.com/forum/t/slug/99 please")])

      link = rows("embed_links").first
      expect(link).to include(url: "https://forum.example.com/forum/t/slug/99")
    end

    it "leaves an absolute link outside the host's prefix alone" do
      raw = "see https://forum.example.com/other/t/slug/99 please"
      processor.process_batch([post_item(raw)])

      expect(rows("embed_links")).to be_empty
      expect(rows("posts").first[:raw]).to eq(raw)
    end
  end

  describe ".combine_results" do
    let(:tracker) { Migrations::Conversion::StepTracker.new }

    def entry
      entries = rows("log_entries")
      expect(entries.size).to eq(1)
      entries.first
    end

    it "merges the workers' host lists into one INFO entry" do
      described_class.combine_results(
        [
          %w[old-forum.example.com legacy.example.com],
          %w[old-forum.example.com another.example.com],
        ],
        tracker,
      )

      expect(tracker.stats.warning_count).to eq(0)
      expect(entry).to include(
        type: Migrations::Database::IntermediateDB::LogEntry::INFO,
        message: described_class::FOREIGN_LINK_LOG_MESSAGE,
      )

      details = JSON.parse(entry[:details])
      expect(details["total"]).to eq(3)
      expect(details["hosts"]).to eq(
        %w[another.example.com legacy.example.com old-forum.example.com],
      )
      expect(details).not_to have_key("omitted")
    end

    it "caps the host list and records how many hosts it dropped" do
      hosts = 501.times.map { |i| format("host%03d.example", i) }

      described_class.combine_results([hosts], tracker)

      details = JSON.parse(entry[:details])
      expect(details["hosts"].size).to eq(500)
      expect(details["omitted"]).to eq(1)
      # `total` still counts every host, dropped ones included.
      expect(details["total"]).to eq(501)
    end

    it "writes nothing for no results" do
      described_class.combine_results([], tracker)

      expect(tracker.stats.warning_count).to eq(0)
      expect(rows("log_entries")).to be_empty
    end
  end
end
