# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

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
