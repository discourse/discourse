# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

  describe "rendering fallbacks" do
    it "keeps the source URL when the link target is unmapped" do
      link =
        create_embed(
          :link,
          url: "https://old.example.com/x",
          text: "See",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      expect(resolve("x #{link} y")).to eq("x [See](https://old.example.com/x) y")
    end

    it "falls back to the recorded username when the user is unmapped" do
      quote = create_embed(:quote, quoted_user_id: 5, quoted_username: "ghost")

      expect(resolve("x #{quote} y")).to eq('x [quote="ghost"] y')
    end

    it "falls back to the recorded name when the user is unmapped" do
      quote =
        create_embed(:quote, quoted_user_id: 5, quoted_username: "ghost", quoted_name: "Ghost User")

      expect(resolve("x #{quote} y")).to eq('x [quote="Ghost User, username:ghost"] y')
    end

    it "omits the username: part when the name equals the username" do
      quote =
        create_embed(:quote, quoted_user_id: 5, quoted_username: "ghost", quoted_name: "ghost")

      expect(resolve("x #{quote} y")).to eq('x [quote="ghost"] y')
    end

    it "renders a bare [quote] when nothing identifies the quoted author" do
      quote = create_embed(:quote)

      expect(resolve("x #{quote} y")).to eq("x [quote] y")
    end

    it "keeps the resolved coordinates when nothing identifies the quoted author" do
      quote = create_embed(:quote, quoted_post_id: 200)
      maps = FakePlaceholderMaps.new(post: { 200 => { topic_id: 9, post_number: 4 } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      # The empty leading segment is what core's header parser needs to read
      # `post:`/`topic:` as coordinates instead of as the username.
      expect(resolved[1]).to eq('x [quote=", post:4, topic:9"] y')
      expect(resolver.unresolved_embeds).to be_empty
    end

    it "rebuilds from what resolved and reports when the quoted post is unmapped" do
      quote = create_embed(:quote, quoted_post_id: 200, quoted_user_id: 5, quoted_username: "sam")
      maps = FakePlaceholderMaps.new(user: { 5 => { username: "sammy" } })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{quote} y" }])

      expect(resolved[1]).to eq('x [quote="sammy"] y')
      expect(resolver.unresolved_embeds).to contain_exactly(
        described_class::UnresolvedEmbed.new(
          kind: :quote,
          entity_id: 200,
          owner_id: 1,
          owner_url: nil,
        ),
      )
    end

    it "reports the source coordinates of a quote that has no resolvable post" do
      # A `post:` with no `topic:` can never resolve to a source post, and the
      # source's own post number is meaningless on the destination.
      quote = create_embed(:quote, quoted_post_number: 2, quoted_username: "sam")

      expect(resolve("x #{quote} y")).to eq('x [quote="sam"] y')
      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["post:2"])
    end

    it "drops an entity-backed embed whose markdown is unavailable" do
      poll = create_embed(:poll, poll_id: 3)

      resolved = resolve("before #{poll} after")

      expect(resolved).to eq("before  after")
      expect(Migrations::Placeholder).not_to be_include(resolved)
    end

    it "keeps backslashes and digits in replacement content verbatim" do
      link = create_embed(:link, url: 'https://old.example.com/a\1b', text: 'C:\temp\readme')

      # A string-argument gsub would eat the backslashes and treat `\1` as a
      # backreference; the block form leaves the text byte-for-byte.
      expect(resolve("x #{link} y")).to eq('x [C:\temp\readme](https://old.example.com/a\1b) y')
    end
  end

  describe "full-URL upload fallback" do
    it "puts the verbatim markdown back and still reports when the sha1 is unmapped" do
      snippet = "![x](/uploads/default/original/2X/a/ab/#{"a" * 40}.png)"
      upload = create_embed(:upload, upload_id: "sha1", original_markdown: snippet)

      expect(resolve("see #{upload} here")).to eq("see #{snippet} here")
      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["sha1"])
    end

    it "declines a foreign-host row even when its sha1 maps, and restores the snippet" do
      snippet = "![x](https://other-forum.example/uploads/original/2X/a/ab/#{"a" * 40}.png)"
      upload =
        create_embed(
          :upload,
          upload_id: "sha1",
          original_markdown: snippet,
          external_host: "other-forum.example",
        )
      # The mapped markdown existing is exactly the dangerous case: a foreign
      # basename colliding with a source upload sha1.
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{upload} y" }])

      expect(resolved[1]).to eq("x #{snippet} y")
      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["sha1"])
    end

    it "maps an external-host row when the host is explicitly trusted" do
      upload =
        create_embed(
          :upload,
          upload_id: "sha1",
          original_markdown: "![x](https://cdn.example.com/uploads/original/sha1.png)",
          external_host: "cdn.example.com",
        )
      maps = FakePlaceholderMaps.new(upload_markdown: { "sha1" => "![x](upload://sha1.png)" })
      resolver =
        described_class.new(
          intermediate_db,
          maps,
          owner_type: embed_owner::POST,
          trusted_upload_hosts: ["CDN.EXAMPLE.COM"],
        )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{upload} y" }])

      expect(resolved[1]).to eq("x ![x](upload://sha1.png) y")
      expect(resolver.unresolved_embeds).to be_empty
    end

    it "prefers the mapped upload markdown over the verbatim snippet" do
      upload =
        create_embed(
          :upload,
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

    it "does not record quotes, external links or mentions (they fall back to source values)" do
      link = placeholder.mint(:link)
      mention = placeholder.mint(:mention)
      quote = placeholder.mint(:quote)
      # A quote that names no post loses nothing when its user is unmapped, so
      # it stays out of the report; only lost coordinates are reported.
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
        owner_id: 100,
        placeholder: quote,
        quoted_username: "ghost",
      )
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

      resolver.resolve_all([{ id: 100, raw: "#{quote} #{link} #{mention}" }])

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
      mention = create_embed(:mention, mention_type: mention_type::USER, target_id: 7)

      expect(resolve("hey #{mention} there")).to eq("hey  there")
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
    it "renders a custom emoji, honoring an import-time rename" do
      emoji = create_embed(:emoji, name: "parrot")
      maps = FakePlaceholderMaps.new(emoji_name: { "parrot" => "party_parrot" })

      expect(resolve("nice #{emoji} work", maps:)).to eq("nice :party_parrot: work")
    end

    it "matches the map regardless of the case the author typed" do
      # The converter records the author's spelling; core lowercases a shortcode
      # before looking it up, so the map is keyed by the folded name.
      emoji = create_embed(:emoji, name: "MYEMOJI")
      maps = FakePlaceholderMaps.new(emoji_name: { "myemoji" => "my_emoji" })

      expect(resolve("hi #{emoji}", maps:)).to eq("hi :my_emoji:")
    end

    it "keeps the author's case on a miss" do
      emoji = create_embed(:emoji, name: "MyEmoji")

      expect(resolve("hi #{emoji}")).to eq("hi :MyEmoji:")
    end

    it "falls back to the source name when the emoji is unmapped, without a report" do
      emoji = create_embed(:emoji, name: "parrot")

      expect(resolve("hi #{emoji}")).to eq("hi :parrot:")
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
