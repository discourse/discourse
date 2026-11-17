# frozen_string_literal: true

# The round-trip contract for embeds that carry their verbatim source: a
# resolution hit rewrites only what resolution changed (a link's destination),
# and any miss restores the exact source substring — never a canonical
# approximation that drops titles, spacing, or a suffix the author didn't
# write.
RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

  describe "links with a verbatim source" do
    # A slug-only topic link resolves through a topic slug lookup; with no
    # topics to look up against, the titled construct restores byte-exact.
    it "restores a slug-only topic link byte-exact when the slug is unknown" do
      original = %{[read this](/t/how-to-fix-it "worth it")}
      token =
        create_embed(
          :link,
          original_markdown: original,
          url: "/t/how-to-fix-it",
          text: "read this",
          target_type: link_target::TOPIC,
          target_name: "how-to-fix-it",
          url_offset: 12,
        )

      expect(resolve("x #{token} y")).to eq("x #{original} y")
    end

    # A multi-tag route names several records; with nothing mapped the whole
    # construct restores byte-exact, filter and suffix included.
    it "restores a category+tag link byte-exact when nothing is mapped" do
      original =
        %{[official plugins](https://old.example.com/tags/c/plugin/22/none/official/l/top "tabs")}
      token =
        create_embed(
          :link,
          original_markdown: original,
          url: "https://old.example.com/tags/c/plugin/22/none/official/l/top",
          text: "official plugins",
          target_type: link_target::CATEGORY_TAG,
          target_id: 22,
          target_tag_path: "none/official",
          target_suffix: "/l/top",
        )

      expect(resolve("x #{token} y")).to eq("x #{original} y")
    end

    it "restores an intersection link byte-exact when a tag is unmapped" do
      url = "https://old.example.com/tags/intersection/food/wine"
      token =
        create_embed(
          :link,
          original_markdown: url,
          url:,
          target_type: link_target::TAG_INTERSECTION,
          target_tag_path: "food/wine",
        )

      expect(resolve("see #{token} there")).to eq("see #{url} there")
    end

    it "restores a titled link byte-exact when the target is unmapped" do
      original = %{[See](https://old.example.com/t/x/300 "why this matters")}
      token =
        create_embed(
          :link,
          original_markdown: original,
          url: "https://old.example.com/t/x/300",
          text: "See",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      expect(resolve("x #{token} y")).to eq("x #{original} y")
    end

    it "rewrites only the destination inside a titled link on a hit" do
      token =
        create_embed(
          :link,
          original_markdown: %{[See](https://old.example.com/t/x/300 "why this matters")},
          url: "https://old.example.com/t/x/300",
          url_offset: "[See](".bytesize,
          text: "See",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve("x #{token} y", maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq(%{x [See](https://dest.example.com/t/12 "why this matters") y})
    end

    # `[](url)` — an empty label is valid CommonMark and stays empty: only
    # the destination span is rewritten, and there is no label span to touch.
    it "rewrites the destination of an empty-label link and keeps the label empty" do
      token =
        create_embed(
          :link,
          original_markdown: "[](https://old.example.com/t/x/300)",
          url: "https://old.example.com/t/x/300",
          url_offset: "[](".bytesize,
          text: "",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq("[](https://dest.example.com/t/12)")
    end

    it "keeps angle brackets and padding around a rewritten destination" do
      token =
        create_embed(
          :link,
          original_markdown: "[x](  <https://old.example.com/t/x/300>  )",
          url: "https://old.example.com/t/x/300",
          url_offset: "[x](  <".bytesize,
          text: "x",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq("[x](  <https://dest.example.com/t/12>  )")
    end

    it "rewrites both spellings of a self-link" do
      url = "https://old.example.com/t/x/300"
      token =
        create_embed(
          :link,
          original_markdown: "[#{url}](#{url})",
          url:,
          url_offset: url.bytesize + 3,
          label_url_offset: 1,
          text: url,
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq("[https://dest.example.com/t/12](https://dest.example.com/t/12)")
    end

    it "leaves a URL the author repeated in the title untouched on a hit" do
      url = "https://old.example.com/t/x/300"
      token =
        create_embed(
          :link,
          original_markdown: %{[docs](#{url} "mirror of #{url}")},
          url:,
          url_offset: "[docs](".bytesize,
          text: "docs",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      # Only the recorded destination span changes; the title is the author's
      # text even when it happens to spell the same URL.
      expect(resolved).to eq(
        %{[docs](https://dest.example.com/t/12 "mirror of https://old.example.com/t/x/300")},
      )
    end

    it "rebuilds canonically on a hit when no destination span was recorded" do
      token =
        create_embed(
          :link,
          original_markdown: %{[See](https://old.example.com/t/x/300 "why this matters")},
          url: "https://old.example.com/t/x/300",
          text: "See",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      # Without a span, a value search over the snippet could hit a title, so
      # the construct is rebuilt from its parts instead (losing the title, but
      # never rewriting the author's prose).
      expect(resolved).to eq("[See](https://dest.example.com/t/12)")
    end

    it "rebuilds canonically on a hit when the recorded span holds other bytes" do
      token =
        create_embed(
          :link,
          original_markdown: %{[See](https://old.example.com/t/x/300 "why this matters")},
          url: "https://old.example.com/t/x/300",
          # In bounds, but pointing at the label instead of the destination. A
          # splice there would write the new URL into the author's prose.
          url_offset: 1,
          text: "See",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq("[See](https://dest.example.com/t/12)")
    end

    it "splices only the destination when the label span holds other bytes" do
      url = "https://old.example.com/t/x/300"
      token =
        create_embed(
          :link,
          original_markdown: "[docs](#{url})",
          url:,
          url_offset: "[docs](".bytesize,
          # In bounds, wrong position: the label span is dropped, the
          # destination span still applies.
          label_url_offset: 1,
          text: "docs",
          target_type: link_target::TOPIC,
          target_id: 300,
        )

      resolved = resolve(token.to_s, maps: FakePlaceholderMaps.new(topic_id: { 300 => 12 }))

      expect(resolved).to eq("[docs](https://dest.example.com/t/12)")
    end

    it "restores an external link byte-exact" do
      original = %{[docs](https://elsewhere.example.org/page "docs")}
      token =
        create_embed(
          :link,
          original_markdown: original,
          url: "https://elsewhere.example.org/page",
          text: "docs",
        )

      expect(resolve(token.to_s)).to eq(original)
    end
  end

  describe "broadcast mentions" do
    it "keeps the author's spelling when the destination names nothing" do
      here = create_embed(:mention, mention_type: mention_type::HERE, name: "Here")
      all = create_embed(:mention, mention_type: mention_type::ALL, name: "ALL")

      resolved = resolve("#{here} and #{all}", maps: FakePlaceholderMaps.new(here_mention: nil))

      expect(resolved).to eq("@Here and @ALL")
    end

    it "keeps the author's spelling when the destination's here-mention is the same name" do
      # Here-matching is case-insensitive at cook time, so `@Here` works on a
      # destination configured with "here"; canonicalizing it would change
      # bytes for nothing.
      token = create_embed(:mention, mention_type: mention_type::HERE, name: "Here")

      expect(resolve("cc #{token}")).to eq("cc @Here")
    end

    it "remaps a here-mention that the destination names differently" do
      token = create_embed(:mention, mention_type: mention_type::HERE, name: "Here")

      resolved = resolve("cc #{token}", maps: FakePlaceholderMaps.new(here_mention: "hier"))

      expect(resolved).to eq("cc @hier")
    end
  end

  describe "hashtags with a verbatim source" do
    it "keeps a bare hashtag bare when the resolved category cannot be rendered" do
      # The import resolved a type (mutating hashtag_type) but the destination
      # map misses: the source never wrote `::category`, so none may appear.
      token =
        create_embed(
          :hashtag,
          original_markdown: "#support",
          name: "support",
          hashtag_type: hashtag_type::CATEGORY,
          target_id: 7,
        )

      expect(resolve("see #{token}")).to eq("see #support")
    end

    it "restores a source-written suffix exactly on a miss" do
      token =
        create_embed(
          :hashtag,
          original_markdown: "#support::tag",
          name: "support",
          hashtag_type: hashtag_type::TAG,
        )

      expect(resolve(token.to_s)).to eq("#support::tag")
    end
  end

  describe "quotes with a verbatim source" do
    it "restores the exact opening tag when nothing resolved" do
      # Header parameters the reference columns don't model survive a miss.
      original = "[quote=bob, custom:keep-me]"
      token = create_embed(:quote, original_markdown: original, quoted_username: "bob")

      expect(resolve("#{token}\ntext\n[/quote]")).to eq("#{original}\ntext\n[/quote]")
    end

    it "restores the source tag and reports when the quoted post did not resolve" do
      # The user resolving is not enough: dropping `post:`/`topic:` would leave
      # an attribution pointing at no post at all.
      original = %{[quote="bob, post:2, topic:3"]}
      token =
        create_embed(
          :quote,
          original_markdown: original,
          quoted_user_id: 5,
          quoted_username: "bob",
          quoted_post_id: 200,
        )

      maps = FakePlaceholderMaps.new(user: { 5 => { username: "robert" } })
      resolver = described_class.new(intermediate_db, maps, owner_type:)

      resolved = resolver.resolve_all([{ id: 1, raw: token.to_s }])[1]

      expect(resolved).to eq(original)
      expect(resolver.unresolved_embeds.map(&:kind)).to eq(%i[quote])
    end

    it "rebuilds canonically once the quoted user resolved" do
      token =
        create_embed(
          :quote,
          original_markdown: %{[QUOTE="bob"]},
          quoted_user_id: 5,
          quoted_username: "bob",
        )

      resolved =
        resolve(token.to_s, maps: FakePlaceholderMaps.new(user: { 5 => { username: "robert" } }))

      expect(resolved).to eq(%{[quote="robert"]})
    end
  end

  describe "uploads with a verbatim source" do
    it "restores the exact source markup when the upload is unmapped" do
      original = "![shot|690x388](upload://abcdef.png)"
      token = create_embed(:upload, upload_id: "abcdef", original_markdown: original)

      expect(resolve(token.to_s)).to eq(original)
      expect(resolver.unresolved_embeds.map(&:kind)).to eq(%i[upload])
    end

    # A failed image paste (`[label|meta](upload://…)`, link position, no `!`)
    # rides the standard upload row: verbatim back on a miss, the
    # destination's own markdown on a hit — same as every other upload form.
    it "round-trips a link-position pipe label through miss and hit" do
      original = "[image|281x500](upload://abcdef.jpeg)"
      token = create_embed(:upload, upload_id: "abcdef", original_markdown: original)

      expect(resolve("x #{token} y")).to eq("x #{original} y")

      hit = FakePlaceholderMaps.new(upload_markdown: { "abcdef" => "![shot](upload://new.jpeg)" })
      expect(resolve("x #{token} y", maps: hit)).to eq("x ![shot](upload://new.jpeg) y")
    end

    it "restores a reference definition's destination when the upload is unmapped" do
      original = "upload://abcdef.jpg"
      token = create_embed(:upload, upload_id: "abcdef", original_markdown: original)

      expect(resolve("[1]: #{token}")).to eq("[1]: #{original}")
      expect(resolver.unresolved_embeds.map(&:kind)).to eq(%i[upload])
    end

    it "restores a prose full URL when the upload is unmapped" do
      original = "https://old.example.com/uploads/default/original/1X/abcdef.jpg"
      token = create_embed(:upload, upload_id: "abcdef", original_markdown: original)

      expect(resolve("see #{token} here")).to eq("see #{original} here")
      expect(resolver.unresolved_embeds.map(&:entity_id)).to eq(["abcdef"])
    end
  end
end
