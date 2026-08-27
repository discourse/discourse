# frozen_string_literal: true

# The round-trip contract for embeds that carry their verbatim source: a
# resolution hit rewrites only what resolution changed (a link's destination),
# and any miss restores the exact source substring — never a canonical
# approximation that drops titles, spacing, or a suffix the author didn't
# write.
RSpec.describe Migrations::Importer::PlaceholderResolver do
  include_context "with placeholder resolver"

  describe "links with a verbatim source" do
    def create_link(placeholder_token, original:, **attributes)
      Migrations::Database::IntermediateDB::EmbedLink.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        original_markdown: original,
        **attributes,
      )
    end

    # A multi-tag route names several records; with nothing mapped the whole
    # construct restores byte-exact, filter and suffix included.
    it "restores a category+tag link byte-exact when nothing is mapped" do
      token = placeholder.mint(:link)
      original =
        %{[official plugins](https://old.example.com/tags/c/plugin/22/none/official/l/top "tabs")}
      create_link(
        token,
        original:,
        url: "https://old.example.com/tags/c/plugin/22/none/official/l/top",
        text: "official plugins",
        target_type: link_target::CATEGORY_TAG,
        target_id: 22,
        target_tag_path: "none/official",
        target_suffix: "/l/top",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{token} y" }])

      expect(resolved[1]).to eq("x #{original} y")
    end

    it "restores an intersection link byte-exact when a tag is unmapped" do
      token = placeholder.mint(:link)
      original = "see https://old.example.com/tags/intersection/food/wine there"
      create_link(
        token,
        original: "https://old.example.com/tags/intersection/food/wine",
        url: "https://old.example.com/tags/intersection/food/wine",
        target_type: link_target::TAG_INTERSECTION,
        target_tag_path: "food/wine",
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{token} there" }])

      expect(resolved[1]).to eq(original)
    end

    it "restores a titled link byte-exact when the target is unmapped" do
      token = placeholder.mint(:link)
      original = %{[See](https://old.example.com/t/x/300 "why this matters")}
      create_link(
        token,
        original:,
        url: "https://old.example.com/t/x/300",
        text: "See",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "x #{token} y" }])

      expect(resolved[1]).to eq("x #{original} y")
    end

    it "rewrites only the destination inside a titled link on a hit" do
      token = placeholder.mint(:link)
      create_link(
        token,
        original: %{[See](https://old.example.com/t/x/300 "why this matters")},
        url: "https://old.example.com/t/x/300",
        url_offset: "[See](".bytesize,
        text: "See",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "x #{token} y" }],
        )

      expect(resolved[1]).to eq(%{x [See](https://dest.example.com/t/12 "why this matters") y})
    end

    # `[](url)` — an empty label is valid CommonMark and stays empty: only
    # the destination span is rewritten, and there is no label span to touch.
    it "rewrites the destination of an empty-label link and keeps the label empty" do
      token = placeholder.mint(:link)
      create_link(
        token,
        original: "[](https://old.example.com/t/x/300)",
        url: "https://old.example.com/t/x/300",
        url_offset: "[](".bytesize,
        text: "",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      expect(resolved[1]).to eq("[](https://dest.example.com/t/12)")
    end

    it "keeps angle brackets and padding around a rewritten destination" do
      token = placeholder.mint(:link)
      create_link(
        token,
        original: "[x](  <https://old.example.com/t/x/300>  )",
        url: "https://old.example.com/t/x/300",
        url_offset: "[x](  <".bytesize,
        text: "x",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      expect(resolved[1]).to eq("[x](  <https://dest.example.com/t/12>  )")
    end

    it "rewrites both spellings of a self-link" do
      token = placeholder.mint(:link)
      url = "https://old.example.com/t/x/300"
      create_link(
        token,
        original: "[#{url}](#{url})",
        url:,
        url_offset: url.bytesize + 3,
        label_url_offset: 1,
        text: url,
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      expect(resolved[1]).to eq("[https://dest.example.com/t/12](https://dest.example.com/t/12)")
    end

    it "leaves a URL the author repeated in the title untouched on a hit" do
      token = placeholder.mint(:link)
      url = "https://old.example.com/t/x/300"
      create_link(
        token,
        original: %{[docs](#{url} "mirror of #{url}")},
        url:,
        url_offset: "[docs](".bytesize,
        text: "docs",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      # Only the recorded destination span changes; the title is the author's
      # text even when it happens to spell the same URL.
      expect(resolved[1]).to eq(
        %{[docs](https://dest.example.com/t/12 "mirror of https://old.example.com/t/x/300")},
      )
    end

    it "rebuilds canonically on a hit when no destination span was recorded" do
      token = placeholder.mint(:link)
      create_link(
        token,
        original: %{[See](https://old.example.com/t/x/300 "why this matters")},
        url: "https://old.example.com/t/x/300",
        text: "See",
        target_type: link_target::TOPIC,
        target_id: 300,
      )

      maps = FakePlaceholderMaps.new(topic_id: { 300 => 12 })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      # Without a span, a value search over the snippet could hit a title, so
      # the construct is rebuilt from its parts instead (losing the title, but
      # never rewriting the author's prose).
      expect(resolved[1]).to eq("[See](https://dest.example.com/t/12)")
    end

    it "restores an external link byte-exact" do
      token = placeholder.mint(:link)
      original = %{[docs](https://elsewhere.example.org/page "docs")}
      create_link(token, original:, url: "https://elsewhere.example.org/page", text: "docs")

      resolved = resolver.resolve_all([{ id: 1, raw: "#{token}" }])

      expect(resolved[1]).to eq(original)
    end
  end

  describe "broadcast mentions" do
    def create_mention(placeholder_token, **attributes)
      Migrations::Database::IntermediateDB::EmbedMention.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        **attributes,
      )
    end

    it "keeps the author's spelling when the destination names nothing" do
      here = placeholder.mint(:mention)
      all = placeholder.mint(:mention)
      create_mention(here, mention_type: mention_type::HERE, name: "Here")
      create_mention(all, mention_type: mention_type::ALL, name: "ALL")

      maps = FakePlaceholderMaps.new(here_mention: nil)
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{here} and #{all}" }],
        )

      expect(resolved[1]).to eq("@Here and @ALL")
    end

    it "keeps the author's spelling when the destination's here-mention is the same name" do
      # Here-matching is case-insensitive at cook time, so `@Here` works on a
      # destination configured with "here"; canonicalizing it would change
      # bytes for nothing.
      token = placeholder.mint(:mention)
      create_mention(token, mention_type: mention_type::HERE, name: "Here")

      resolved = resolver.resolve_all([{ id: 1, raw: "cc #{token}" }])

      expect(resolved[1]).to eq("cc @Here")
    end

    it "remaps a here-mention that the destination names differently" do
      token = placeholder.mint(:mention)
      create_mention(token, mention_type: mention_type::HERE, name: "Here")

      maps = FakePlaceholderMaps.new(here_mention: "hier")
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "cc #{token}" }],
        )

      expect(resolved[1]).to eq("cc @hier")
    end
  end

  describe "hashtags with a verbatim source" do
    def create_hashtag(placeholder_token, original:, **attributes)
      Migrations::Database::IntermediateDB::EmbedHashtag.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        original_markdown: original,
        **attributes,
      )
    end

    it "keeps a bare hashtag bare when the resolved category cannot be rendered" do
      token = placeholder.mint(:hashtag)
      # The import resolved a type (mutating hashtag_type) but the destination
      # map misses: the source never wrote `::category`, so none may appear.
      create_hashtag(
        token,
        original: "#support",
        name: "support",
        hashtag_type: hashtag_type::CATEGORY,
        target_id: 7,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "see #{token}" }])

      expect(resolved[1]).to eq("see #support")
    end

    it "restores a source-written suffix exactly on a miss" do
      token = placeholder.mint(:hashtag)
      create_hashtag(
        token,
        original: "#support::tag",
        name: "support",
        hashtag_type: hashtag_type::TAG,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "#{token}" }])

      expect(resolved[1]).to eq("#support::tag")
    end
  end

  describe "quotes with a verbatim source" do
    def create_quote(placeholder_token, original:, **attributes)
      Migrations::Database::IntermediateDB::EmbedQuote.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: placeholder_token,
        original_markdown: original,
        **attributes,
      )
    end

    it "restores the exact opening tag when nothing resolved" do
      token = placeholder.mint(:quote)
      # Header parameters the reference columns don't model survive a miss.
      original = "[quote=bob, custom:keep-me]"
      create_quote(token, original:, quoted_username: "bob")

      resolved = resolver.resolve_all([{ id: 1, raw: "#{token}\ntext\n[/quote]" }])

      expect(resolved[1]).to eq("#{original}\ntext\n[/quote]")
    end

    it "rebuilds canonically once the quoted user resolved" do
      token = placeholder.mint(:quote)
      create_quote(token, original: %{[QUOTE="bob"]}, quoted_user_id: 5, quoted_username: "bob")

      maps = FakePlaceholderMaps.new(user: { 5 => { username: "robert" } })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "#{token}" }],
        )

      expect(resolved[1]).to eq(%{[quote="robert"]})
    end
  end

  describe "uploads with a verbatim source" do
    it "restores the exact source markup when the upload is unmapped" do
      token = placeholder.mint(:upload)
      original = "![shot|690x388](upload://abcdef.png)"
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: token,
        upload_id: "abcdef",
        original_markdown: original,
      )

      resolved = resolver.resolve_all([{ id: 1, raw: "#{token}" }])

      expect(resolved[1]).to eq(original)
      expect(resolver.unresolved_embeds.map(&:kind)).to eq(%i[upload])
    end

    # A failed image paste (`[label|meta](upload://…)`, link position, no `!`)
    # rides the standard upload row: verbatim back on a miss, the
    # destination's own markdown on a hit — same as every other upload form.
    it "round-trips a link-position pipe label through miss and hit" do
      token = placeholder.mint(:upload)
      original = "[image|281x500](upload://abcdef.jpeg)"
      Migrations::Database::IntermediateDB::EmbedUpload.create(
        owner_type: embed_owner::POST,
        owner_id: 1,
        placeholder: token,
        upload_id: "abcdef",
        original_markdown: original,
      )

      expect(resolver.resolve_all([{ id: 1, raw: "x #{token} y" }])[1]).to eq("x #{original} y")

      maps = FakePlaceholderMaps.new(upload_markdown: { "abcdef" => "![shot](upload://new.jpeg)" })
      resolved =
        described_class.new(intermediate_db, maps, owner_type:).resolve_all(
          [{ id: 1, raw: "x #{token} y" }],
        )
      expect(resolved[1]).to eq("x ![shot](upload://new.jpeg) y")
    end
  end
end
