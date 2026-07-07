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
  subject(:resolver) { described_class.new(intermediate_db, maps, owner_type:) }

  EmbedOwner = Migrations::Database::IntermediateDB::Enums::EmbedOwner
  LinkTarget = Migrations::Database::IntermediateDB::Enums::LinkTarget

  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }
  let(:intermediate_db) { @intermediate_db }
  let(:maps) { FakePlaceholderMaps.new }
  let(:owner_type) { EmbedOwner::POST }

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

      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: quote,
        quoted_post_id: 200,
        quoted_user_id: 5,
      )
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_type: LinkTarget::TOPIC,
        target_id: 300,
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: mention,
        mention_type: "user",
        target_id: 7,
        name: "stale-name",
      )
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
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
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      raw = "Q #{quote} L #{link} M #{mention} U #{upload} end"

      resolved = resolver.resolve_all([{ id: 100, raw: }])

      expect(resolved[100]).to eq(
        'Q [quote="Alice A, post:3, topic:42, username:alice"] ' \
          "L [See](https://dest.example.com/t/99) M  @bob  U ![pic](upload://sha1.png) end",
      )
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
    end

    it "resolves a batch of owners, loading linkage rows once" do
      first = placeholder.mint(:mention)
      second = placeholder.mint(:mention)

      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: first,
        mention_type: "all",
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 2,
        placeholder: second,
        mention_type: "here",
      )

      resolved =
        resolver.resolve_all([{ id: 1, raw: "a #{first} b" }, { id: 2, raw: "c #{second} d" }])

      expect(resolved).to eq({ 1 => "a  @all  b", 2 => "c  @here  d" })
    end

    it "only loads linkage rows of its own owner_type" do
      token = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::USER,
        owner_id: 1,
        placeholder: token,
        mention_type: "all",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "a #{token} b" }])

      # The row belongs to a user, not a post, so the token is an orphan here.
      expect(resolved[1]).to eq("a  b")
      expect(resolver.orphan_sink.map(&:placeholder)).to eq([token])
    end

    it "leaves a body untouched when it has no linkage rows" do
      expect(resolver.resolve_all([{ id: 9, raw: "plain body" }])).to eq({ 9 => "plain body" })
    end

    it "issues no linkage queries when no owner in the batch has a token" do
      allow(intermediate_db).to receive(:query).and_call_original

      resolved = resolver.resolve_all([{ id: 1, raw: "plain" }, { id: 2, raw: "also plain" }])

      expect(intermediate_db).not_to have_received(:query)
      expect(resolved).to eq({ 1 => "plain", 2 => "also plain" })
    end

    it "loads only the owners that carry a token" do
      token = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 2,
        placeholder: token,
        mention_type: "all",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "plain" }, { id: 2, raw: "hi #{token}" }])

      expect(resolved).to eq({ 1 => "plain", 2 => "hi  @all " })
    end
  end

  describe "link target dispatch" do
    it "rewrites a topic target through the topic map" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        target_type: LinkTarget::TOPIC,
        target_id: 300,
      )
      maps = FakePlaceholderMaps.new(topic_id: { 300 => 99 })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://dest.example.com/t/99 y")
    end

    it "rewrites a post target through the post map" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        target_type: LinkTarget::POST,
        target_id: 200,
      )
      maps = FakePlaceholderMaps.new(post: { 200 => { topic_id: 42, post_number: 3 } })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://dest.example.com/t/42/3 y")
    end

    it "keeps the source URL for a link without a target" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://elsewhere.example.com/page",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://elsewhere.example.com/page y")
    end
  end

  describe "rendering fallbacks" do
    it "keeps the source URL when the link target is unmapped" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_type: LinkTarget::TOPIC,
        target_id: 300,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x [See](https://old.example.com/x) y")
    end

    it "falls back to the recorded username when the user is unmapped" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_user_id: 5,
        quoted_username: "ghost",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="ghost"] y')
    end

    it "falls back to the recorded name when the user is unmapped" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_user_id: 5,
        quoted_username: "ghost",
        quoted_name: "Ghost User",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="Ghost User, username:ghost"] y')
    end

    it "renders a bare [quote] when nothing identifies the quoted author" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: quote,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq("x [quote] y")
    end

    it "drops an entity-backed embed whose markdown is unavailable" do
      poll = placeholder.mint(:poll)
      Migrations::Database::IntermediateDB::EmbedPoll.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: poll,
        poll_id: 3,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "before #{poll} after" }])

      expect(resolved[1]).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved[1])
    end

    it "keeps backslashes and digits in replacement content verbatim" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
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

  describe "full-URL upload fallback" do
    it "puts the verbatim markdown back and still reports when the sha1 is unmapped" do
      upload = placeholder.mint(:upload)
      snippet = "![x](/uploads/default/original/2X/a/ab/#{"a" * 40}.png)"
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: upload,
        upload_id: "sha1",
        original_markdown: snippet,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{upload} here" }])

      expect(resolved[1]).to eq("see #{snippet} here")
      expect(resolver.unresolved_sink.map(&:entity_id)).to eq(["sha1"])
    end

    it "prefers the mapped upload markdown over the verbatim snippet" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: upload,
        upload_id: "sha1",
        original_markdown: "![x](/uploads/default/original/2X/a/ab/old.png)",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{upload} y" }])

      expect(resolved[1]).to eq("x ![x](upload://sha1.png) y")
      expect(resolver.unresolved_sink).to be_empty
    end
  end

  describe "#unresolved_sink" do
    let(:maps) { FakePlaceholderMaps.new(post: { 100 => { topic_id: 42, post_number: 3 } }) }

    it "records each entity-backed embed the maps can't resolve, with the owner URL" do
      upload = placeholder.mint(:upload)
      poll = placeholder.mint(:poll)
      event = placeholder.mint(:event)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      Migrations::Database::IntermediateDB::EmbedPoll.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: poll,
        poll_id: 7,
      )
      Migrations::Database::IntermediateDB::EmbedEvent.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: event,
        event_id: 9,
      )

      resolver.resolve_all([{ id: 100, raw: "#{upload} #{poll} #{event}" }])

      expect(resolver.unresolved_sink).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :upload,
          entity_id: "sha1",
          owner_id: 100,
          owner_url: "https://dest.example.com/t/42/3",
        ),
        described_class::UnresolvedEmbed.new(
          kind: :poll,
          entity_id: 7,
          owner_id: 100,
          owner_url: "https://dest.example.com/t/42/3",
        ),
        described_class::UnresolvedEmbed.new(
          kind: :event,
          entity_id: 9,
          owner_id: 100,
          owner_url: "https://dest.example.com/t/42/3",
        ),
      )
    end

    it "does not record entity-backed embeds that resolve" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.unresolved_sink).to be_empty
    end

    it "does not record quotes, links or mentions (they fall back to source values)" do
      link = placeholder.mint(:link)
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: mention,
        mention_type: "user",
        name: "ghost",
      )

      resolver.resolve_all([{ id: 100, raw: "#{link} #{mention}" }])

      expect(resolver.unresolved_sink).to be_empty
    end

    it "leaves the owner URL nil when the containing post is unmapped" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 555,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 555, raw: "x #{upload} y" }])

      expect(resolver.unresolved_sink.first.owner_url).to be_nil
    end

    it "accumulates across resolve_all calls for the run" do
      first = placeholder.mint(:upload)
      second = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: first,
        upload_id: "a",
      )
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: second,
        upload_id: "b",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{first} y" }])
      resolver.resolve_all([{ id: 100, raw: "x #{second} y" }])

      expect(resolver.unresolved_sink.map(&:entity_id)).to eq(%w[a b])
    end

    it "writes to an injected sink instead of buffering in memory" do
      sink = []
      resolver =
        described_class.new(
          intermediate_db,
          maps,
          owner_type: EmbedOwner::POST,
          unresolved_sink: sink,
        )
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
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

    it "strips a token with no linkage row and records it with the owner URL" do
      orphan = placeholder.mint(:quote)

      resolved = resolver.resolve_all([{ id: 100, raw: "before #{orphan} after" }])

      expect(resolved[100]).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
      expect(resolver.orphan_sink).to contain_exactly(
        described_class::OrphanPlaceholder.new(
          kind: "quote",
          owner_id: 100,
          owner_url: "https://dest.example.com/t/42/3",
          placeholder: orphan,
        ),
      )
    end

    it "strips an orphan while still resolving a real embed in the same body" do
      upload = placeholder.mint(:upload)
      orphan = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
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
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 100, raw: "#{upload} and #{orphan}" }])

      expect(resolved[100]).to eq("![x](upload://sha1.png) and ")
      expect(resolver.orphan_sink.map(&:placeholder)).to eq([orphan])
      expect(resolver.orphan_sink.map(&:kind)).to eq(["link"])
    end

    it "records nothing when every token has a linkage row" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.orphan_sink).to be_empty
    end

    it "leaves the owner URL nil when the containing post is unmapped" do
      orphan = placeholder.mint(:quote)

      resolver.resolve_all([{ id: 555, raw: "x #{orphan} y" }])

      expect(resolver.orphan_sink.first).to have_attributes(owner_id: 555, owner_url: nil)
    end
  end

  describe "resolving a quoted post by source coordinates" do
    def create_quote(placeholder_token, **attrs)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        **attrs,
      )
    end

    it "fills quoted_post_id from (topic_id, post_number) and feeds the maps flow" do
      Migrations::Database::IntermediateDB::Post.create(
        original_id: 200,
        topic_id: 5,
        post_number: 12,
        raw: "quoted body",
      )
      quote = placeholder.mint(:quote)
      create_quote(quote, quoted_topic_id: 5, quoted_post_number: 12, quoted_username: "bob")
      maps = FakePlaceholderMaps.new(post: { 200 => { topic_id: 42, post_number: 3 } })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="bob, post:3, topic:42"] y')
    end

    it "falls back to the username when the coordinates match no post" do
      quote = placeholder.mint(:quote)
      create_quote(quote, quoted_topic_id: 5, quoted_post_number: 99, quoted_username: "bob")

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="bob"] y')
    end
  end

  describe "resolving recorded names to source original_ids" do
    it "maps a quoted username to the user's original_id, honoring an import-time rename" do
      Migrations::Database::IntermediateDB::User.create(
        original_id: 5,
        username: "bob",
        created_at: Time.now,
        trust_level: 0,
      )
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_username: "bob",
      )
      # The importer renamed user 5 to "robert"; resolving the recorded name to id 5
      # lets the quote pick up the new username instead of the stale source one.
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "robert", name: nil } })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="robert"] y')
    end

    it "maps a user mention name to the user's original_id, honoring an import-time rename" do
      Migrations::Database::IntermediateDB::User.create(
        original_id: 7,
        username: "bob",
        created_at: Time.now,
        trust_level: 0,
      )
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: "user",
        name: "bob",
      )
      maps = FakePlaceholderMaps.new(user: { 7 => { username: "robert", name: "Robert" } })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "hey #{mention}!" }])

      expect(resolved[1]).to eq("hey  @robert !")
    end

    it "maps a group mention name to the group's original_id" do
      Migrations::Database::IntermediateDB::Group.create(original_id: 3, name: "admins")
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: "group",
        name: "admins",
      )
      maps = FakePlaceholderMaps.new(group_name: { 3 => "staff" })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "cc #{mention} please" }])

      expect(resolved[1]).to eq("cc  @staff  please")
    end

    it "matches a recorded name to a source username regardless of case and Unicode form" do
      Migrations::Database::IntermediateDB::User.create(
        original_id: 9,
        username: "Café".unicode_normalize(:nfd),
        created_at: Time.now,
        trust_level: 0,
      )
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: EmbedOwner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: "user",
        name: "CAFÉ".unicode_normalize(:nfc),
      )
      maps = FakePlaceholderMaps.new(user: { 9 => { username: "cafe", name: nil } })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "ping #{mention}" }])

      expect(resolved[1]).to eq("ping  @cafe ")
    end
  end

  describe "a USER-owned batch" do
    let(:owner_type) { EmbedOwner::USER }
    let(:maps) { FakePlaceholderMaps.new(user: { 7 => { username: "alice", name: "Alice A" } }) }

    it "resolves embeds recorded against a user's markdown" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::USER,
        owner_id: 7,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: EmbedOwner::USER)

      resolved = resolver.resolve_all([{ id: 7, raw: "bio #{upload} end" }])

      expect(resolved[7]).to eq("bio ![x](upload://sha1.png) end")
    end

    it "reports the user's profile URL for an unresolved embed" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: EmbedOwner::USER,
        owner_id: 7,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 7, raw: "bio #{upload} end" }])

      expect(resolver.unresolved_sink).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :upload,
          entity_id: "sha1",
          owner_id: 7,
          owner_url: "https://dest.example.com/u/alice",
        ),
      )
    end

    it "reports the user's profile URL for an orphan token" do
      orphan = placeholder.mint(:quote)

      resolver.resolve_all([{ id: 7, raw: "bio #{orphan} end" }])

      expect(resolver.orphan_sink).to contain_exactly(
        described_class::OrphanPlaceholder.new(
          kind: "quote",
          owner_id: 7,
          owner_url: "https://dest.example.com/u/alice",
          placeholder: orphan,
        ),
      )
    end

    it "leaves the owner URL nil when the user is unmapped" do
      orphan = placeholder.mint(:quote)

      resolver.resolve_all([{ id: 99, raw: "bio #{orphan} end" }])

      expect(resolver.orphan_sink.first).to have_attributes(owner_id: 99, owner_url: nil)
    end
  end
end
