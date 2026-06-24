# frozen_string_literal: true

require "tmpdir"

# A minimal stand-in for the import maps. Production wiring (mappings DB, uploads
# store, Discourse base URL) lands with the Posts import step; the resolver only
# depends on this small duck-typed surface.
class FakePlaceholderMaps
  def initialize(**lookups)
    @lookups = lookups
  end

  %i[user group_name post topic_id upload_markdown poll_markdown event_markdown].each do |name|
    define_method(name) { |original_id| (@lookups[name] || {})[original_id] }
  end

  def base_url
    @lookups.fetch(:base_url, "https://dest.example.com")
  end
end

RSpec.describe Migrations::Importer::PlaceholderResolver do
  subject(:resolver) { described_class.new(intermediate_db, maps) }

  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }
  let(:intermediate_db) { @intermediate_db }
  let(:maps) { FakePlaceholderMaps.new }

  around do |example|
    Dir.mktmpdir do |dir|
      db_path = File.join(dir, "intermediate.db")
      Migrations::Database.migrate(
        db_path,
        migrations_path: Migrations::Database::INTERMEDIATE_DB_SCHEMA_PATH,
      )
      @intermediate_db = Migrations::Database.connect(db_path)
      Migrations::Database::IntermediateDB.setup(@intermediate_db)
      example.run
    ensure
      Migrations::Database::IntermediateDB.setup(nil)
    end
  end

  describe "#resolve_all" do
    it "rewrites every kind of token using the maps" do
      quote = placeholder.mint(:quote)
      link = placeholder.mint(:link)
      mention = placeholder.mint(:mention)
      upload = placeholder.mint(:upload)

      Migrations::Database::IntermediateDB::PostQuote.create(
        post_id: 100,
        placeholder: quote,
        quoted_post_id: 200,
        quoted_user_id: 5,
      )
      Migrations::Database::IntermediateDB::PostLink.create(
        post_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_topic_id: 300,
      )
      Migrations::Database::IntermediateDB::PostMention.create(
        post_id: 100,
        placeholder: mention,
        mention_type: "user",
        target_id: 7,
        name: "stale-name",
      )
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      maps =
        FakePlaceholderMaps.new(
          user: {
            5 => {
              username: "alice",
              name: "Alice A",
            },
            7 => {
              username: "bob",
              name: "Bob",
            },
          },
          post: {
            200 => {
              topic_id: 42,
              post_number: 3,
            },
          },
          topic_id: {
            300 => 99,
          },
          upload_markdown: {
            "sha1" => "![pic](upload://sha1.png)",
          },
        )
      resolver = described_class.new(intermediate_db, maps)

      raw = "Q #{quote} L #{link} M #{mention} U #{upload} end"

      resolved = resolver.resolve_all([{ id: 100, raw: }])

      expect(resolved[100]).to eq(
        'Q [quote="Alice A, post:3, topic:42, username:alice"] ' \
          "L [See](https://dest.example.com/t/99) M  @bob  U ![pic](upload://sha1.png) end",
      )
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
    end

    it "resolves a batch of posts, loading linkage rows once" do
      first = placeholder.mint(:mention)
      second = placeholder.mint(:mention)

      Migrations::Database::IntermediateDB::PostMention.create(
        post_id: 1,
        placeholder: first,
        mention_type: "all",
      )
      Migrations::Database::IntermediateDB::PostMention.create(
        post_id: 2,
        placeholder: second,
        mention_type: "here",
      )

      resolved =
        resolver.resolve_all([{ id: 1, raw: "a #{first} b" }, { id: 2, raw: "c #{second} d" }])

      expect(resolved).to eq({ 1 => "a  @all  b", 2 => "c  @here  d" })
    end

    it "leaves a body untouched when it has no linkage rows" do
      expect(resolver.resolve_all([{ id: 9, raw: "plain body" }])).to eq({ 9 => "plain body" })
    end
  end

  describe "rendering fallbacks" do
    it "keeps the source URL when the link target is unmapped" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::PostLink.create(
        post_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_topic_id: 300,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x [See](https://old.example.com/x) y")
    end

    it "falls back to the recorded username when the user is unmapped" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::PostQuote.create(
        post_id: 1,
        placeholder: quote,
        quoted_user_id: 5,
        quoted_username: "ghost",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="ghost"] y')
    end

    it "renders a bare [quote] when nothing identifies the quoted author" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::PostQuote.create(post_id: 1, placeholder: quote)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq("x [quote] y")
    end

    it "drops an entity-backed embed whose markdown is unavailable" do
      poll = placeholder.mint(:poll)
      Migrations::Database::IntermediateDB::PostPoll.create(
        post_id: 1,
        placeholder: poll,
        poll_id: 3,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "before #{poll} after" }])

      expect(resolved[1]).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved[1])
    end

    it "keeps backslashes and digits in replacement content verbatim" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::PostLink.create(
        post_id: 1,
        placeholder: link,
        url: 'https://old.example.com/a\1b',
        text: 'C:\temp\readme',
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      # A string-argument gsub would eat the backslashes and treat `\1` as a
      # backreference; the block form leaves the text byte-for-byte.
      expect(resolved[1]).to eq('x [C:\temp\readme](https://old.example.com/a\1b) y')
    end
  end

  describe "#unresolved_sink" do
    let(:maps) { FakePlaceholderMaps.new(post: { 100 => { topic_id: 42, post_number: 3 } }) }

    it "records each entity-backed embed the maps can't resolve, with the post URL" do
      upload = placeholder.mint(:upload)
      poll = placeholder.mint(:poll)
      event = placeholder.mint(:event)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      Migrations::Database::IntermediateDB::PostPoll.create(
        post_id: 100,
        placeholder: poll,
        poll_id: 7,
      )
      Migrations::Database::IntermediateDB::PostEvent.create(
        post_id: 100,
        placeholder: event,
        event_id: 9,
      )

      resolver.resolve_all([{ id: 100, raw: "#{upload} #{poll} #{event}" }])

      expect(resolver.unresolved_sink).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :upload,
          entity_id: "sha1",
          post_id: 100,
          post_url: "https://dest.example.com/t/42/3",
        ),
        described_class::UnresolvedEmbed.new(
          kind: :poll,
          entity_id: 7,
          post_id: 100,
          post_url: "https://dest.example.com/t/42/3",
        ),
        described_class::UnresolvedEmbed.new(
          kind: :event,
          entity_id: 9,
          post_id: 100,
          post_url: "https://dest.example.com/t/42/3",
        ),
      )
    end

    it "does not record entity-backed embeds that resolve" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps)

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.unresolved_sink).to be_empty
    end

    it "does not record quotes, links or mentions (they fall back to source values)" do
      link = placeholder.mint(:link)
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::PostLink.create(
        post_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
      )
      Migrations::Database::IntermediateDB::PostMention.create(
        post_id: 100,
        placeholder: mention,
        mention_type: "user",
        name: "ghost",
      )

      resolver.resolve_all([{ id: 100, raw: "#{link} #{mention}" }])

      expect(resolver.unresolved_sink).to be_empty
    end

    it "leaves the post URL nil when the containing post is unmapped" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 555,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 555, raw: "x #{upload} y" }])

      expect(resolver.unresolved_sink.first.post_url).to be_nil
    end

    it "accumulates across resolve_all calls for the run" do
      first = placeholder.mint(:upload)
      second = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: first,
        upload_id: "a",
      )
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: second,
        upload_id: "b",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{first} y" }])
      resolver.resolve_all([{ id: 100, raw: "x #{second} y" }])

      expect(resolver.unresolved_sink.map(&:entity_id)).to eq(%w[a b])
    end

    it "writes to an injected sink instead of buffering in memory" do
      sink = []
      resolver = described_class.new(intermediate_db, maps, unresolved_sink: sink)
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(sink.map(&:entity_id)).to eq(["sha1"])
      expect(resolver.unresolved_sink).to be(sink)
    end
  end

  describe "#orphan_sink" do
    let(:maps) { FakePlaceholderMaps.new(post: { 100 => { topic_id: 42, post_number: 3 } }) }

    it "strips a token with no linkage row and records it with the post URL" do
      orphan = placeholder.mint(:quote)

      resolved = resolver.resolve_all([{ id: 100, raw: "before #{orphan} after" }])

      expect(resolved[100]).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
      expect(resolver.orphan_sink).to contain_exactly(
        described_class::OrphanPlaceholder.new(
          kind: "quote",
          post_id: 100,
          post_url: "https://dest.example.com/t/42/3",
          placeholder: orphan,
        ),
      )
    end

    it "strips an orphan while still resolving a real embed in the same body" do
      upload = placeholder.mint(:upload)
      orphan = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps =
        FakePlaceholderMaps.new(
          post: {
            100 => {
              topic_id: 42,
              post_number: 3,
            },
          },
          upload_markdown: {
            "sha1" => "![x](upload://sha1.png)",
          },
        )
      resolver = described_class.new(intermediate_db, maps)

      resolved = resolver.resolve_all([{ id: 100, raw: "#{upload} and #{orphan}" }])

      expect(resolved[100]).to eq("![x](upload://sha1.png) and ")
      expect(resolver.orphan_sink.map(&:placeholder)).to eq([orphan])
      expect(resolver.orphan_sink.map(&:kind)).to eq(["link"])
    end

    it "records nothing when every token has a linkage row" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::PostUpload.create(
        post_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.orphan_sink).to be_empty
    end

    it "leaves the post URL nil when the containing post is unmapped" do
      orphan = placeholder.mint(:quote)

      resolver.resolve_all([{ id: 555, raw: "x #{orphan} y" }])

      expect(resolver.orphan_sink.first).to have_attributes(post_id: 555, post_url: nil)
    end
  end
end
