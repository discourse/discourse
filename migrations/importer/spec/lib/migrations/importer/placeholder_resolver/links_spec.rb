# frozen_string_literal: true

RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

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

    it "resolves a post target addressed by source coordinates" do
      Migrations::Database::IntermediateDB::Post.create(
        original_id: 500,
        topic_id: 12,
        post_number: 3,
        raw: "body",
      )
      maps = FakePlaceholderMaps.new(post: { 500 => { topic_id: 42, post_number: 7 } })

      resolved =
        render(
          {
            url: "/t/slug/12/3",
            target_type: link_target::POST,
            target_topic_id: 12,
            target_post_number: 3,
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/t/42/7 y")
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
end
