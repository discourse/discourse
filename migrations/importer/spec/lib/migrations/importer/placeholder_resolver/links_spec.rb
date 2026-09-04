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

    it "rewrites a SITE link's origin, keeping its path, query and fragment" do
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: "https://old.example.com/faq?x=1#y",
        target_type: link_target::SITE,
        target_suffix: "/faq?x=1#y",
      )
      maps = FakePlaceholderMaps.new
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://dest.example.com/faq?x=1#y y")
      expect(resolver.unresolved_embeds).to be_empty
    end

    it "writes a SITE suffix back in the author's spelling" do
      # The suffix is stored as the author wrote it — a quote stays a quote,
      # never the percent-encoding the parser's normalized href used.
      link = placeholder.mint(:link)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: link,
        url: %{https://old.example.com/new?public_key="abc"},
        target_type: link_target::SITE,
        target_suffix: %{/new?public_key="abc"},
      )
      maps = FakePlaceholderMaps.new
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq(%{x https://dest.example.com/new?public_key="abc" y})
      expect(resolver.unresolved_embeds).to be_empty
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
    def render(attrs, maps:)
      resolve("x #{create_embed(:link, **attrs)} y", maps:)
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

    it "reattaches a category's filter tail after the destination id" do
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
            url: "/c/support/billing/2/l/latest",
            target_type: link_target::CATEGORY,
            target_id: 2,
            target_suffix: "/l/latest",
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/c/support/billing/20/l/latest y")
    end

    # A multi-tag route names several records; it is rebuilt only when the
    # category and every tag map, and any miss restores the source URL.
    describe "multi-tag routes" do
      let(:category_tag_maps) do
        FakePlaceholderMaps.new(
          category_id: {
            2 => 20,
          },
          category_slug_path: {
            2 => "addons:plugin",
          },
          tag_name: {
            3 => "official-stuff",
          },
        )
      end

      before { create_tag(3, "official") }

      it "renders a category+tag target from the mapped coordinates" do
        resolved =
          render(
            {
              url: "/tags/c/plugin/2/official",
              target_type: link_target::CATEGORY_TAG,
              target_id: 2,
              target_tag_path: "official",
            },
            maps: category_tag_maps,
          )

        expect(resolved).to eq(
          "x https://dest.example.com/tags/c/addons/plugin/20/official-stuff y",
        )
      end

      it "keeps the subcategory filter and the suffix around the mapped parts" do
        resolved =
          render(
            {
              url: "/tags/c/plugin/2/none/official/l/top?period=yearly",
              target_type: link_target::CATEGORY_TAG,
              target_id: 2,
              target_tag_path: "none/official",
              target_suffix: "/l/top?period=yearly",
            },
            maps: category_tag_maps,
          )

        expect(resolved).to eq(
          "x https://dest.example.com/tags/c/addons/plugin/20/none/official-stuff/l/top?period=yearly y",
        )
      end

      it "resolves a legacy slug-path category the way category links do" do
        create_category(7, "howto")
        create_category(8, "devs", parent_category_id: 7)
        maps =
          FakePlaceholderMaps.new(
            category_id: {
              8 => 80,
            },
            category_slug_path: {
              8 => "guides:devs",
            },
            tag_name: {
              3 => "official",
            },
          )

        resolved =
          render(
            {
              url: "/tags/c/howto/devs/official",
              target_type: link_target::CATEGORY_TAG,
              target_name: "howto:devs",
              target_tag_path: "official",
            },
            maps:,
          )

        expect(resolved).to eq("x https://dest.example.com/tags/c/guides/devs/80/official y")
      end

      it "renders an intersection target with every tag mapped" do
        create_tag(4, "wine")
        maps = FakePlaceholderMaps.new(tag_name: { 3 => "official", 4 => "vino" })

        resolved =
          render(
            {
              url: "/tags/intersection/official/wine",
              target_type: link_target::TAG_INTERSECTION,
              target_tag_path: "official/wine",
            },
            maps:,
          )

        expect(resolved).to eq("x https://dest.example.com/tags/intersection/official/vino y")
      end

      it "treats a lone none/all segment as the tag, not as a subcategory filter" do
        create_tag(5, "none")
        maps =
          FakePlaceholderMaps.new(
            category_id: {
              2 => 20,
            },
            category_slug_path: {
              2 => "addons:plugin",
            },
            tag_name: {
              5 => "nothing",
            },
          )

        resolved =
          render(
            {
              url: "/tags/c/plugin/2/none",
              target_type: link_target::CATEGORY_TAG,
              target_id: 2,
              target_tag_path: "none",
            },
            maps:,
          )

        expect(resolved).to eq("x https://dest.example.com/tags/c/addons/plugin/20/nothing y")
      end

      it "falls back to the source URL when the category does not map" do
        maps = FakePlaceholderMaps.new(tag_name: { 3 => "official" })

        resolved =
          render(
            {
              url: "/tags/c/plugin/2/official",
              target_type: link_target::CATEGORY_TAG,
              target_id: 2,
              target_tag_path: "official",
            },
            maps:,
          )

        # The report itself flows through the shared unresolved-link branch,
        # covered below with the other miss cases.
        expect(resolved).to eq("x /tags/c/plugin/2/official y")
      end

      it "falls back whole when one of the intersection tags does not map" do
        create_tag(4, "wine")
        maps = FakePlaceholderMaps.new(tag_name: { 3 => "official" })

        resolved =
          render(
            {
              url: "/tags/intersection/official/wine",
              target_type: link_target::TAG_INTERSECTION,
              target_tag_path: "official/wine",
            },
            maps:,
          )

        expect(resolved).to eq("x /tags/intersection/official/wine y")
      end

      it "falls back when a tag name is not a source tag at all" do
        resolved =
          render(
            {
              url: "/tags/c/plugin/2/mystery",
              target_type: link_target::CATEGORY_TAG,
              target_id: 2,
              target_tag_path: "mystery",
            },
            maps: category_tag_maps,
          )

        expect(resolved).to eq("x /tags/c/plugin/2/mystery y")
      end
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

    # A slug-only `/t/<slug>` link carries no id; the slug resolves against the
    # source topics, and only an unambiguous one rewrites.

    it "resolves a slug-only topic link when exactly one topic carries the slug" do
      create_topic(300, "how-to-fix-it")
      maps = FakePlaceholderMaps.new(topic_id: { 300 => 99 })

      resolved =
        render(
          {
            url: "/t/how-to-fix-it?page=2",
            target_type: link_target::TOPIC,
            target_name: "how-to-fix-it",
            target_suffix: "?page=2",
          },
          maps:,
        )

      expect(resolved).to eq("x https://dest.example.com/t/99?page=2 y")
    end

    it "restores the source URL for an unknown slug" do
      url = "https://old.example.com/t/ghost-topic"

      resolved =
        render({ url:, target_type: link_target::TOPIC, target_name: "ghost-topic" }, maps:)

      expect(resolved).to eq("x #{url} y")
    end

    it "restores the source URL when several topics share the slug" do
      create_topic(300, "dup-slug")
      create_topic(301, "dup-slug")
      link =
        create_embed(
          :link,
          url: "https://old.example.com/t/dup-slug",
          target_type: link_target::TOPIC,
          target_name: "dup-slug",
        )
      maps = FakePlaceholderMaps.new(topic_id: { 300 => 99, 301 => 100 })
      resolver = described_class.new(intermediate_db, maps, owner_type: embed_owner::POST)

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolved[1]).to eq("x https://old.example.com/t/dup-slug y")
      expect(resolver.unresolved_embeds.map(&:kind)).to eq([:link])
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
      link =
        create_embed(
          :link,
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
      link =
        create_embed(:link, url: "/u/ghost", target_type: link_target::USER, target_name: "ghost")

      resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["ghost"])
    end

    it "does not report an external link that falls back" do
      link = create_embed(:link, url: "https://elsewhere.example.com/page")

      resolver.resolve_all([{ id: 1, raw: "x #{link} y" }])

      expect(resolver.unresolved_embeds).to be_empty
    end
  end
end
