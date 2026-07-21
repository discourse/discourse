# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

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
end
