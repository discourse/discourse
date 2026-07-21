# frozen_string_literal: true

require "tmpdir"

# A minimal stand-in for the import maps. Production wiring (mappings DB, uploads
# store, Discourse base URL) lands with the Posts import step; the resolver only
# depends on this small duck-typed surface.
class FakePlaceholderMaps
  def initialize(**lookups)
    @lookups = lookups
  end

  %i[
    user
    group_name
    post
    topic_id
    upload_markdown
    poll_markdown
    event_markdown
    category_slug_path
    category_id
    tag_name
    badge
    emoji_name
  ].each { |name| define_method(name) { |key| (@lookups[name] || {})[key] } }

  def base_url
    @lookups.fetch(:base_url, "https://dest.example.com")
  end

  def here_mention
    @lookups.fetch(:here_mention, "here")
  end
end

RSpec.describe Migrations::Importer::PlaceholderResolver do
  subject(:resolver) { described_class.new(intermediate_db, maps, owner_type:) }

  let(:hashtag_type) { Migrations::Database::IntermediateDB::Enums::HashtagType }
  let(:mention_type) { Migrations::Database::IntermediateDB::Enums::MentionType }
  let(:link_target) { Migrations::Database::IntermediateDB::Enums::LinkTarget }
  let(:embed_owner) { Migrations::Database::IntermediateDB::Enums::EmbedOwner }

  let(:placeholder) { Migrations::Placeholder.new(nonce: "n") }
  let(:intermediate_db) { @intermediate_db }
  let(:maps) { FakePlaceholderMaps.new }
  let(:owner_type) { embed_owner::POST }

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
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: quote,
        quoted_post_id: 200,
        quoted_user_id: 5,
      )
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_type: link_target::TOPIC,
        target_id: 300,
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: mention,
        mention_type: mention_type::USER,
        target_id: 7,
        name: "stale-name",
      )
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
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
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      raw = "Q #{quote} L #{link} M #{mention} U #{upload} end"

      resolved = resolver.resolve_all([{ id: 100, raw: }])

      expect(resolved[100]).to eq(
        'Q [quote="Alice A, post:3, topic:42, username:alice"] ' \
          "L [See](https://dest.example.com/t/99) M @bob U ![pic](upload://sha1.png) end",
      )
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
    end

    it "resolves a batch of owners" do
      first = placeholder.mint(:mention)
      second = placeholder.mint(:mention)

      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: first,
        mention_type: mention_type::ALL,
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 2,
        placeholder: second,
        mention_type: mention_type::HERE,
      )

      resolved =
        resolver.resolve_all([{ id: 1, raw: "a #{first} b" }, { id: 2, raw: "c #{second} d" }])

      expect(resolved).to eq({ 1 => "a @all b", 2 => "c @here d" })
    end

    it "renders a here mention with the destination's configured here_mention name" do
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: mention_type::HERE,
      )
      maps = FakePlaceholderMaps.new(here_mention: "hier")
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "cc #{mention} please" }])

      expect(resolved[1]).to eq("cc @hier please")
    end

    it "only loads linkage rows of its own owner_type" do
      token = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::USER,
        owner_id: 1,
        placeholder: token,
        mention_type: mention_type::ALL,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "a #{token} b" }])

      # The row belongs to a user, not a post, so the token is an orphan here.
      expect(resolved[1]).to eq("a  b")
      expect(resolver.orphan_placeholders.map(&:placeholder)).to eq([token])
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
        owner_type: embed_owner::POST,
        owner_id: 2,
        placeholder: token,
        mention_type: mention_type::ALL,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "plain" }, { id: 2, raw: "hi #{token}" }])

      expect(resolved).to eq({ 1 => "plain", 2 => "hi @all" })
    end
  end

  describe "link target dispatch" do
    it "rewrites a topic target through the topic map" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        target_type: link_target::TOPIC,
        target_id: 300,
      )
      maps = FakePlaceholderMaps.new(topic_id: { 300 => 99 })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://dest.example.com/t/99 y")
    end

    it "rewrites a post target through the post map" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        target_type: link_target::POST,
        target_id: 200,
      )
      maps = FakePlaceholderMaps.new(post: { 200 => { topic_id: 42, post_number: 3 } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://dest.example.com/t/42/3 y")
    end

    it "keeps the source URL for a link without a target" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://elsewhere.example.com/page",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://elsewhere.example.com/page y")
    end
  end

  describe "internal link resolution" do
    def create_link(placeholder_token, **attrs)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        **attrs,
      )
    end

    def create_user(original_id, username)
      Migrations::Database::IntermediateDB::User.create(
        original_id:,
        username:,
        created_at: Time.now,
        trust_level: 0,
      )
    end

    def create_category(original_id, slug, parent_category_id: nil)
      Migrations::Database::IntermediateDB::Category.create(
        original_id:,
        name: slug,
        slug:,
        parent_category_id:,
        user_id: 1,
      )
    end

    def create_tag(original_id, name)
      Migrations::Database::IntermediateDB::Tag.create(original_id:, name:, slug: name)
    end

    def render(attrs, maps:)
      link = placeholder.mint(:link)
      create_link(link, **attrs)
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)
      resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])[1]
    end

    # Rendering a resolved target through the maps (the id is already known here;
    # normalization of names/coordinates is exercised separately below).

    it "renders a user target, honoring an import-time rename" do
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "new_bob" } })

      resolved = render({ url: "/u/bob", target_type: link_target::USER, target_id: 5 }, maps:)

      expect(resolved).to eq("x https://dest.example.com/u/new_bob y")
    end

    it "renders a group target, honoring an import-time rename" do
      maps = FakePlaceholderMaps.new(group_name: { 8 => "new_team" })

      resolved = render({ url: "/g/team", target_type: link_target::GROUP, target_id: 8 }, maps:)

      expect(resolved).to eq("x https://dest.example.com/g/new_team y")
    end

    it "renders a tag target, honoring an import-time rename" do
      maps = FakePlaceholderMaps.new(tag_name: { 3 => "shipped" })

      resolved = render({ url: "/tag/release", target_type: link_target::TAG, target_id: 3 }, maps:)

      expect(resolved).to eq("x https://dest.example.com/tag/shipped y")
    end

    it "renders a category target as its slug path plus the destination id" do
      maps =
        FakePlaceholderMaps.new(
          category_id: {
            2 => 20,
          },
          category_slug_path: {
            2 => "support:billing",
          },
        )

      resolved = render({ url: "/c/x/2", target_type: link_target::CATEGORY, target_id: 2 }, maps:)

      expect(resolved).to eq("x https://dest.example.com/c/support/billing/20 y")
    end

    it "renders a badge target with the destination id and slug" do
      maps = FakePlaceholderMaps.new(badge: { 9 => { id: 90, slug: "great-work" } })

      resolved =
        render({ url: "/badges/9/x", target_type: link_target::BADGE, target_id: 9 }, maps:)

      expect(resolved).to eq("x https://dest.example.com/badges/90/great-work y")
    end

    it "reattaches the suffix to the rebuilt URL" do
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "bob" } })

      resolved =
        render(
          {
            url: "/u/bob/summary",
            target_type: link_target::USER,
            target_id: 5,
            target_suffix: "/summary",
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/u/bob/summary y")
    end

    it "keeps a link's text, wrapping the rebuilt URL" do
      maps = FakePlaceholderMaps.new(topic_id: { 300 => 99 })

      resolved =
        render(
          {
            url: "/t/slug/300",
            text: "the topic",
            target_type: link_target::TOPIC,
            target_id: 300,
          },
          maps:,
        )

      expect(resolved).to eq("x [the topic](https://dest.example.com/t/99) y")
    end

    # Normalizing what the converter could only record by name or coordinates into a
    # target_id, then rendering it.

    it "resolves a user target by name, honoring an import-time rename" do
      create_user(5, "old_bob")
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "new_bob" } })

      resolved =
        render({ url: "/u/old_bob", target_type: link_target::USER, target_name: "old_bob" }, maps:)

      expect(resolved).to eq("x https://dest.example.com/u/new_bob y")
    end

    it "resolves a category target by its parent:child slug path" do
      create_category(1, "support")
      create_category(2, "billing", parent_category_id: 1)
      maps =
        FakePlaceholderMaps.new(
          category_id: {
            2 => 20,
          },
          category_slug_path: {
            2 => "support:billing",
          },
        )

      resolved =
        render(
          {
            url: "/c/support/billing",
            target_type: link_target::CATEGORY,
            target_name: "support:billing",
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/c/support/billing/20 y")
    end

    it "resolves a deeply nested category target by its full grandparent:parent:child path" do
      create_category(1, "grandparent")
      create_category(2, "parent", parent_category_id: 1)
      create_category(3, "child", parent_category_id: 2)
      maps =
        FakePlaceholderMaps.new(
          category_id: {
            3 => 30,
          },
          category_slug_path: {
            3 => "grandparent:parent:child",
          },
        )

      resolved =
        render(
          {
            url: "/c/grandparent/parent/child",
            target_type: link_target::CATEGORY,
            target_name: "grandparent:parent:child",
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/c/grandparent/parent/child/30 y")
    end

    it "resolves a tag target by name, folding a synonym onto its target" do
      create_tag(3, "release")
      create_tag(4, "releases")
      Migrations::Database::IntermediateDB::TagSynonym.create(synonym_tag_id: 4, target_tag_id: 3)
      maps = FakePlaceholderMaps.new(tag_name: { 3 => "shipped" })

      resolved =
        render(
          { url: "/tag/releases", target_type: link_target::TAG, target_name: "releases" },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/tag/shipped y")
    end

    # Reporting: an internal link that can't be resolved falls back to the source URL
    # but is still recorded, since a stale internal link points at the wrong record.

    it "falls back to the source URL and reports an unresolved internal link" do
      link = placeholder.mint(:link)
      create_link(
        link,
        url: "https://old.example.com/t/slug/300",
        target_type: link_target::TOPIC,
        target_id: 300,
      )
      maps = FakePlaceholderMaps.new(post: { 1 => { topic_id: 42, post_number: 3 } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://old.example.com/t/slug/300 y")
      expect(resolver.unresolved_embeds).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :link,
          entity_id: 300,
          owner_id: 1,
          owner_url: "https://dest.example.com/t/42/3",
        ),
      )
    end

    it "reports the failing name when a named target can't be resolved" do
      link = placeholder.mint(:link)
      create_link(link, url: "/u/ghost", target_type: link_target::USER, target_name: "ghost")

      resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["ghost"])
    end

    it "does not report an external link that falls back" do
      link = placeholder.mint(:link)
      create_link(link, url: "https://elsewhere.example.com/page")

      resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolver.unresolved_embeds).to be_empty
    end
  end

  describe "rendering fallbacks" do
    it "keeps the source URL when the link target is unmapped" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/x",
        text: "See",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x [See](https://old.example.com/x) y")
    end

    it "falls back to the recorded username when the user is unmapped" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
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
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_user_id: 5,
        quoted_username: "ghost",
        quoted_name: "Ghost User",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="Ghost User, username:ghost"] y')
    end

    it "omits the username: part when the name equals the username" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_user_id: 5,
        quoted_username: "ghost",
        quoted_name: "ghost",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="ghost"] y')
    end

    it "renders a bare [quote] when nothing identifies the quoted author" do
      quote = placeholder.mint(:quote)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: quote,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq("x [quote] y")
    end

    it "drops an entity-backed embed whose markdown is unavailable" do
      poll = placeholder.mint(:poll)
      Migrations::Database::IntermediateDB::EmbedPoll.create(
        owner_type: embed_owner::POST,
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
        owner_type: embed_owner::POST,
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
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: upload,
        upload_id: "sha1",
        original_markdown: snippet,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{upload} here" }])

      expect(resolved[1]).to eq("see #{snippet} here")
      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["sha1"])
    end

    it "prefers the mapped upload markdown over the verbatim snippet" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: upload,
        upload_id: "sha1",
        original_markdown: "![x](/uploads/default/original/2X/a/ab/old.png)",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{upload} y" }])

      expect(resolved[1]).to eq("x ![x](upload://sha1.png) y")
      expect(resolver.unresolved_embeds).to be_empty
    end
  end

  describe "#unresolved_embeds" do
    let(:maps) { FakePlaceholderMaps.new(post: { 100 => { topic_id: 42, post_number: 3 } }) }

    it "records each entity-backed embed the maps can't resolve, with the owner URL" do
      upload = placeholder.mint(:upload)
      poll = placeholder.mint(:poll)
      event = placeholder.mint(:event)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      Migrations::Database::IntermediateDB::EmbedPoll.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: poll,
        poll_id: 7,
      )
      Migrations::Database::IntermediateDB::EmbedEvent.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: event,
        event_id: 9,
      )

      resolver.resolve_all([{ id: 100, raw: "#{upload} #{poll} #{event}" }])

      expect(resolver.unresolved_embeds).to contain_exactly(
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
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.unresolved_embeds).to be_empty
    end

    it "does not record quotes, external links or mentions (they fall back to source values)" do
      link = placeholder.mint(:link)
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: link,
        url: "https://old.example.com/x",
      )
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: mention,
        mention_type: mention_type::USER,
        name: "ghost",
      )

      resolver.resolve_all([{ id: 100, raw: "#{link} #{mention}" }])

      expect(resolver.unresolved_embeds).to be_empty
    end

    it "leaves the owner URL nil when the containing post is unmapped" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 555,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 555, raw: "x #{upload} y" }])

      expect(resolver.unresolved_embeds.first.owner_url).to be_nil
    end

    it "accumulates across resolve_all calls for the run" do
      first = placeholder.mint(:upload)
      second = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: first,
        upload_id: "a",
      )
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: second,
        upload_id: "b",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{first} y" }])
      resolver.resolve_all([{ id: 100, raw: "x #{second} y" }])

      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(%w[a b])
    end

    it "writes to an injected collector instead of buffering in memory" do
      collector = []
      resolver =
        described_class.new(
          intermediate_db,
          maps,
          owner_type: embed_owner::POST,
          unresolved_embeds: collector,
        )
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(collector.map(&:entity_id)).to eq(["sha1"])
      expect(resolver.unresolved_embeds).to be(collector)
    end
  end

  describe "#orphan_placeholders" do
    let(:maps) { FakePlaceholderMaps.new(post: { 100 => { topic_id: 42, post_number: 3 } }) }

    it "strips a token with no linkage row and records it with the owner URL" do
      orphan = placeholder.mint(:quote)

      resolved = resolver.resolve_all([{ id: 100, raw: "before #{orphan} after" }])

      expect(resolved[100]).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved[100])
      expect(resolver.orphan_placeholders).to contain_exactly(
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
        owner_type: embed_owner::POST,
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
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 100, raw: "#{upload} and #{orphan}" }])

      expect(resolved[100]).to eq("![x](upload://sha1.png) and ")
      expect(resolver.orphan_placeholders.map(&:placeholder)).to eq([orphan])
      expect(resolver.orphan_placeholders.map(&:kind)).to eq(["link"])
    end

    it "records nothing when every token has a linkage row" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 100, raw: "x #{upload} y" }])

      expect(resolver.orphan_placeholders).to be_empty
    end

    it "leaves the owner URL nil when the containing post is unmapped" do
      orphan = placeholder.mint(:quote)

      resolver.resolve_all([{ id: 555, raw: "x #{orphan} y" }])

      expect(resolver.orphan_placeholders.first).to have_attributes(owner_id: 555, owner_url: nil)
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
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: quote,
        quoted_username: "bob",
      )
      # The importer renamed user 5 to "robert"; resolving the recorded name to id 5
      # lets the quote pick up the new username instead of the stale source one.
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "robert", name: nil } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

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
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: mention_type::USER,
        name: "bob",
      )
      maps = FakePlaceholderMaps.new(user: { 7 => { username: "robert", name: "Robert" } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "hey #{mention}!" }])

      expect(resolved[1]).to eq("hey @robert!")
    end

    it "maps a group mention name to the group's original_id" do
      Migrations::Database::IntermediateDB::Group.create(original_id: 3, name: "admins")
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: mention_type::GROUP,
        name: "admins",
      )
      maps = FakePlaceholderMaps.new(group_name: { 3 => "staff" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "cc #{mention} please" }])

      expect(resolved[1]).to eq("cc @staff please")
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
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: mention_type::USER,
        name: "CAFÉ".unicode_normalize(:nfc),
      )
      maps = FakePlaceholderMaps.new(user: { 9 => { username: "cafe", name: nil } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "ping #{mention}" }])

      expect(resolved[1]).to eq("ping @cafe")
    end
  end

  describe "a mention that renders to nothing" do
    it "drops the mention and records it" do
      mention = placeholder.mint(:mention)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: mention,
        mention_type: mention_type::USER,
        target_id: 7,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "hey #{mention} there" }])

      expect(resolved[1]).to eq("hey  there")
      expect(resolver.unresolved_embeds).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :mention,
          entity_id: 7,
          owner_id: 1,
          owner_url: nil,
        ),
      )
    end
  end

  describe "hashtag resolution" do
    def create_hashtag(placeholder_token, **attrs)
      Migrations::Database::IntermediateDB::EmbedHashtag.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        **attrs,
      )
    end

    def create_category(original_id, slug, parent_category_id: nil)
      Migrations::Database::IntermediateDB::Category.create(
        original_id:,
        name: slug,
        slug:,
        parent_category_id:,
        user_id: 1,
      )
    end

    def create_tag(original_id, name)
      Migrations::Database::IntermediateDB::Tag.create(original_id:, name:, slug: name)
    end

    it "resolves a bare hashtag to a category, honoring an import-time slug rename" do
      create_category(10, "support")
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "support")
      maps = FakePlaceholderMaps.new(category_slug_path: { 10 => "help" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{hashtag}" }])

      expect(resolved[1]).to eq("see #help")
    end

    it "resolves a parent:child hashtag by its full slug path" do
      create_category(10, "support")
      create_category(11, "billing", parent_category_id: 10)
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "support:billing")
      maps = FakePlaceholderMaps.new(category_slug_path: { 11 => "support:billing" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "in #{hashtag}" }])

      expect(resolved[1]).to eq("in #support:billing")
    end

    it "prefers a top-level category over a child sharing the same bare slug" do
      create_category(10, "news")
      create_category(20, "parent")
      create_category(21, "news", parent_category_id: 20)
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "news")
      maps = FakePlaceholderMaps.new(category_slug_path: { 10 => "news", 21 => "parent:news" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "#{hashtag}" }])

      expect(resolved[1]).to eq("#news")
    end

    it "resolves a bare hashtag to a tag when no category matches, always suffixing ::tag" do
      create_tag(30, "release")
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "release")
      maps = FakePlaceholderMaps.new(tag_name: { 30 => "shipped" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "tagged #{hashtag}" }])

      expect(resolved[1]).to eq("tagged #shipped::tag")
    end

    it "folds a tag synonym onto its target tag" do
      create_tag(30, "release")
      create_tag(31, "ship")
      Migrations::Database::IntermediateDB::TagSynonym.create(synonym_tag_id: 31, target_tag_id: 30)
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "ship")
      maps = FakePlaceholderMaps.new(tag_name: { 30 => "release" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "#{hashtag}" }])

      expect(resolved[1]).to eq("#release::tag")
    end

    it "skips category precedence when the source forced the tag type" do
      create_category(10, "release")
      create_tag(30, "release")
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "release", hashtag_type: hashtag_type::TAG)
      maps =
        FakePlaceholderMaps.new(
          category_slug_path: {
            10 => "release",
          },
          tag_name: {
            30 => "release",
          },
        )
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "#{hashtag}" }])

      # The forced tag wins over the same-named category, and renders with ::tag.
      expect(resolved[1]).to eq("#release::tag")
    end

    it "rebuilds the source text for an unresolved hashtag, keeping a source-forced suffix" do
      forced = placeholder.mint(:hashtag)
      bare = placeholder.mint(:hashtag)
      create_hashtag(forced, name: "ghost", hashtag_type: hashtag_type::CATEGORY)
      create_hashtag(bare, name: "missing")
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "a #{forced} b #{bare} c" }])

      expect(resolved[1]).to eq("a #ghost::category b #missing c")
      expect(resolver.unresolved_embeds).to be_empty
    end

    it "rebuilds the source text when the name resolved but the destination dropped it" do
      create_category(10, "support")
      hashtag = placeholder.mint(:hashtag)
      create_hashtag(hashtag, name: "support")
      # Category resolves against the IDB, but the maps have no destination slug for it.
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{hashtag}" }])

      expect(resolved[1]).to eq("see #support::category")
      expect(resolver.unresolved_embeds).to be_empty
    end
  end

  describe "custom emoji" do
    def create_emoji(placeholder_token, name)
      Migrations::Database::IntermediateDB::EmbedEmoji.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        name:,
      )
    end

    it "renders a custom emoji, honoring an import-time rename" do
      emoji = placeholder.mint(:emoji)
      create_emoji(emoji, "parrot")
      maps = FakePlaceholderMaps.new(emoji_name: { "parrot" => "party_parrot" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "nice #{emoji} work" }])

      expect(resolved[1]).to eq("nice :party_parrot: work")
    end

    it "falls back to the source name when the emoji is unmapped, without a report" do
      emoji = placeholder.mint(:emoji)
      create_emoji(emoji, "parrot")
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "hi #{emoji}" }])

      expect(resolved[1]).to eq("hi :parrot:")
      expect(resolver.unresolved_embeds).to be_empty
    end
  end

  describe "a USER-owned batch" do
    let(:owner_type) { embed_owner::USER }
    let(:maps) { FakePlaceholderMaps.new(user: { 7 => { username: "alice", name: "Alice A" } }) }

    it "resolves embeds recorded against a user's markdown" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::USER,
        owner_id: 7,
        placeholder: upload,
        upload_id: "sha1",
      )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::USER)

      resolved = resolver.resolve_all([{ id: 7, raw: "bio #{upload} end" }])

      expect(resolved[7]).to eq("bio ![x](upload://sha1.png) end")
    end

    it "reports the user's profile URL for an unresolved embed" do
      upload = placeholder.mint(:upload)
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::USER,
        owner_id: 7,
        placeholder: upload,
        upload_id: "sha1",
      )

      resolver.resolve_all([{ id: 7, raw: "bio #{upload} end" }])

      expect(resolver.unresolved_embeds).to contain_exactly(
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

      expect(resolver.orphan_placeholders).to contain_exactly(
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

      expect(resolver.orphan_placeholders.first).to have_attributes(owner_id: 99, owner_url: nil)
    end
  end
end
