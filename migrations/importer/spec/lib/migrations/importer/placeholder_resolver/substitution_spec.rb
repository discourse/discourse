# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

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
end
