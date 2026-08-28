# frozen_string_literal: true

# The engine tier end to end: RawExtractor with a real MarkdownEngine::Context,
# so the constructs come out of the actual discourse-markdown-it parse and the
# positions out of count matching. The engine context needs no Rails, so
# this runs in the isolated suite.
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  let(:custom_emoji_names) { %w[parrot] }
  let(:category_slugs) { %w[support] }
  let(:tag_names) { %w[release] }
  let(:internal_link_hosts) { { "forum.example.com" => nil } }
  let(:refusals) { [] }

  let(:markdown_engine) do
    MarkdownEngineHelper.context_for(
      category_slugs:,
      tag_names:,
      custom_emoji_names:,
      settings: {
        "unicode_usernames" => true,
      },
    )
  end

  let(:on_engine_refusal) { ->(cause, _detail) { refusals << cause } }

  describe "code shielding through the real parse" do
    it "replaces the prose mention and leaves the code-span one alone" do
      output = extract("`@bob` in code and @alice in prose")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to start_with("`@bob` in code and ")
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "replaces the prose copy and leaves the fenced copy of the same name" do
      output = extract("@alice wrote:\n\n```\n@alice\n```\n")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("```\n@alice\n```")
      expect(output).to start_with(buffer.mentions.first[:placeholder])
    end

    it "confirms the prose copy by substitution when the same name also sits in a code span" do
      output = extract("`@alice` and @alice")

      # Count matching cannot split the pair, but the substitution pass confirms
      # the prose occurrence positionally: substituting it removes a mention
      # from the parse, substituting the code-span copy removes nothing.
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to eq("`@alice` and #{buffer.mentions.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "confirms every prose copy when several are mixed with a code-span copy" do
      # Three raw occurrences against two engine mentions: count matching
      # refuses, substitution confirms exactly the two prose ones, and every construct
      # the engine reported is then placed — nothing stays on the tally.
      output = extract("@alice, `@alice` and @alice")

      expect(buffer.mentions.size).to eq(2)
      expect(output).to include("`@alice`")
      expect(refusals).to be_empty
      expect(extractor.engine_refusals).to be_empty
    end
  end

  describe "gate agreement" do
    it "defers nothing for a plain quote block, so the gate may skip it" do
      # The mention forces the engine path; the plain [quote] block riding
      # along yields no embed — which is why TierGate's quote candidacy can
      # require the metadata-bearing `[quote=` shape and stay a superset of
      # what extraction defers.
      extract("[quote]\nquoted prose\n[/quote]\n\n@alice")

      expect(buffer.quotes).to be_empty
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(extractor.engine_bound?("[quote]\nquoted prose\n[/quote]")).to be(false)
    end

    it "matches a decomposed hashtag spelling against its composed name" do
      composed = "café"
      engine =
        MarkdownEngineHelper.context_for(
          tag_names: [composed],
          settings: {
            "unicode_usernames" => true,
          },
        )
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:
            Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize(composed)]),
          markdown_engine: engine,
        )

      decomposed = "café"
      output = extractor.extract("tagged #{"#" + decomposed} here")

      expect(buffer.hashtags.size).to eq(1)
      expect(buffer.hashtags.first[:original_markdown]).to eq("##{decomposed}")
      expect(output).to eq("tagged #{buffer.hashtags.first[:placeholder]} here")
    end
  end

  describe "constructs on the engine tier" do
    it "extracts hashtags and custom emoji" do
      output = extract("`c` #support and :parrot: but not :smile:")

      expect(buffer.hashtags.map { |row| row[:name] }).to eq(%w[support])
      expect(buffer.emojis.map { |row| row[:name] }).to eq(%w[parrot])
      expect(output).to include(":smile:")
    end

    it "extracts an upload image whole, keeping its alt and dimensions in the row source" do
      raw = "see `code`\n\n![pic|100x100](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png)"
      output = extract(raw)

      expect(buffer.uploads.size).to eq(1)
      expect(buffer.uploads.first[:original_markdown]).to eq(
        "![pic|100x100](upload://2Yjf3WE4KOQ88YUb4fUMubKB9My.png)",
      )
      expect(output).to end_with(buffer.uploads.first[:placeholder])
    end

    it "extracts a titled internal link with its verbatim source" do
      extract(%{read [topic](https://forum.example.com/t/slug/5 "context") `x`})

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:original_markdown]).to eq(
        %{[topic](https://forum.example.com/t/slug/5 "context")},
      )
    end

    it "extracts a bare internal link" do
      extract("`x` and https://forum.example.com/t/slug/5 ends it")

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first[:url]).to eq("https://forum.example.com/t/slug/5")
    end

    it "covers both occurrences of a self-link with one node" do
      raw = "[https://forum.example.com/t/slug/5](https://forum.example.com/t/slug/5) `x`"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(output).to start_with(buffer.links.first[:placeholder])
      expect(output).not_to include("forum.example.com")
    end

    it "rewrites a reference-link definition in place" do
      raw = "so [topic][1] `x`\n\n[1]: https://forum.example.com/t/slug/5\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(output).to include("[topic][1]")
      expect(output).to include("[1]: #{buffer.links.first[:placeholder]}")
    end

    it "remaps the single-line quote form the line-oriented walks cannot take" do
      raw = %{[quote="alice, post:2, topic:5"]inline body[/quote]}
      output = extract(raw)

      expect(buffer.quotes.first).to include(
        quoted_username: "alice",
        quoted_post_number: 2,
        quoted_topic_id: 5,
        original_markdown: %{[quote="alice, post:2, topic:5"]},
      )
      expect(output).to end_with("inline body[/quote]")
    end

    it "extracts a quote opener and the mention inside its body" do
      output = extract(%{`x`\n[quote="bob, post:1, topic:2"]\nthanks @alice\n[/quote]})

      expect(buffer.quotes.first).to include(quoted_username: "bob")
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("[/quote]")
    end
  end

  describe "fail-closed behavior" do
    it "extracts an angle-bracket destination whole" do
      extract("[x](<https://forum.example.com/t/slug/5>) `y`")

      expect(buffer.links.first).to include(
        url: "https://forum.example.com/t/slug/5",
        original_markdown: "[x](<https://forum.example.com/t/slug/5>)",
      )
    end

    it "refuses a recognized link no grammar can take, instead of calling it handled" do
      # CommonMark allows an escaped `]` inside a label; the construct grammar
      # does not, so the matched destination cannot be anchored to a node.
      # The reference is real and stays stale — that must land on the
      # must-resolve tally, never report as success. The mention beside it is
      # still extracted.
      raw = "@alice sees [a \\] b](https://forum.example.com/t/slug/5) `y`"
      output = extract(raw)

      expect(buffer.links).to be_empty
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("[a \\] b](https://forum.example.com/t/slug/5)")
      expect(refusals).to eq(%i[unanchored])
    end

    it "leaves an external link untouched" do
      raw = "`x` [docs](https://elsewhere.example.org/page)"
      output = extract(raw)

      expect(output).to eq(raw)
      expect(buffer.links).to be_empty
      expect(refusals).to be_empty
    end

    it "extracts the literal mention and keeps the entity-spelled one on the tally" do
      output = extract("@alice and &#64;bob `x`")

      # The engine decodes `&#64;bob` into a mention no literal byte sequence
      # spells, so no substitution check can confirm it — it stays verbatim and keeps the
      # body's cause. The literal mention next to it is confirmed by substitution and
      # extracted anyway.
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("&#64;bob")
      expect(output).to start_with(buffer.mentions.first[:placeholder])
      expect(refusals).to eq(%i[entity])
    end

    it "extracts from CR line endings through the map-free substitution pass" do
      output = extract("@alice\r\nhello `x`")

      # Count matching cannot index a CR body (markdown-it normalizes CR
      # away before its line maps), but the substitution check's token delta needs no
      # maps at all.
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to eq("#{buffer.mentions.first[:placeholder]}\r\nhello `x`")
      expect(refusals).to be_empty
    end
  end

  describe "soundness regressions" do
    it "rewrites the prose spelling, not an equivalent spelling inside code" do
      # The engine links the schemeless prose URL and normalizes its href to
      # the scheme-ful form — which happens to sit inside the code span. A
      # per-reading count would match the code span and corrupt it; the
      # span union counts both spellings and the substitution check confirms only the prose
      # one is live.
      raw = "`http://forum.example.com/t/slug/5` and forum.example.com/t/slug/5"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first).to include(
        url: "forum.example.com/t/slug/5",
        target_id: 5,
        original_markdown: "forum.example.com/t/slug/5",
      )
      expect(output).to start_with("`http://forum.example.com/t/slug/5` and ")
      expect(output).to end_with(buffer.links.first[:placeholder])
      expect(refusals).to be_empty
    end

    it "rewrites a relative reference definition" do
      raw = "see [old topic][1] `x`\n\n[1]: /t/slug/5\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first).to include(url: "/t/slug/5", target_id: 5)
      expect(output).to include("[1]: #{buffer.links.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "rewrites one reference definition that several links share" do
      # Two link tokens, one raw destination: replacing the definition
      # rewrites both links, so one row is enough.
      raw =
        "see [profile][prefs] and [settings][prefs] `x`\n\n" \
          "[prefs]: https://forum.example.com/t/slug/5\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first).to include(url: "https://forum.example.com/t/slug/5", target_id: 5)
      expect(output).to include("[prefs]: #{buffer.links.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "rewrites several distinct shared definitions in one body" do
      raw =
        "see [a][1], [b][1], [c][2] and [d][2] `x`\n\n" \
          "[1]: https://forum.example.com/t/slug/5\n[2]: https://forum.example.com/t/slug/7\n"
      output = extract(raw)

      expect(buffer.links.map { |row| row[:target_id] }).to contain_exactly(5, 7)
      buffer.links.each { |row| expect(output).to include(row[:placeholder]) }
      expect(refusals).to be_empty
    end

    it "rewrites a shared definition but not a copy of its URL inside code" do
      # The code-span copy makes the raw count two against two link tokens —
      # a bare count equality would attribute the code span to the
      # definition's reuse. The definition rule refuses that; the substitution
      # checks confirm the definition (both tokens vanish) and skip the code copy
      # (nothing changes).
      raw =
        "see [a][1] and [b][1] and `https://forum.example.com/t/slug/5`\n\n" \
          "[1]: https://forum.example.com/t/slug/5\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(output).to include("`https://forum.example.com/t/slug/5`")
      expect(output).to include("[1]: #{buffer.links.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "refuses a body with more distinct tracked URLs than the value cap" do
      count = Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::MAX_URL_VALUES + 1
      raw = (1..count).map { |i| "https://forum.example.com/t/s/#{i}" }.join(" ")
      output = extract(raw)

      expect(output).to eq(raw)
      expect(buffer.links).to be_empty
      expect(refusals).to eq(%i[url_volume])
    end

    it "reports quote headers beyond the substitution limit instead of calling them handled" do
      # CR endings force every quote onto the substitution path; two more quotes
      # than MAX_SUBSTITUTIONS leaves two headers stale, which must show up on the
      # tally rather than reading as a fully handled body.
      quotes = (1..50).map { |i| "[quote=\"alice, post:#{i}, topic:9\"]\r\nbody #{i}\r\n[/quote]" }
      output = extract(quotes.join("\r\n"))

      expect(buffer.quotes.size).to eq(48)
      expect(output.scan(/\[quote=/).size).to eq(2)
      expect(refusals).to eq(%i[substitution_limit])
    end

    it "keeps a non-default port as part of the host identity, scheme-aware" do
      raw = [
        "on `x`:",
        "https://forum.example.com:80/t/slug/5",
        "http://forum.example.com:443/t/slug/5",
        "//forum.example.com:8443/t/slug/5 done",
      ].join("\n")
      output = extract(raw)

      # `:80` is only default for http and `:443` only for https; a
      # protocol-relative URL has no scheme to default from. None of these
      # origins is the configured host, so none is a construct — and none is
      # a refusal either, external links never are.
      expect(buffer.links).to be_empty
      expect(output).to eq(raw)
      expect(refusals).to be_empty
    end

    context "with a subdirectory install" do
      let(:internal_link_hosts) { { "forum.example.com" => "/forum" } }

      it "tracks only paths inside the host's prefix" do
        raw =
          "`x` [a](https://forum.example.com/other/page) " \
            "and https://forum.example.com/forum/t/slug/5"
        output = extract(raw)

        # The sibling app's path is not the forum's; it must neither be
        # rewritten nor refused, while the in-prefix URL resolves normally.
        expect(buffer.links.size).to eq(1)
        expect(buffer.links.first).to include(target_id: 5)
        expect(output).to include("[a](https://forum.example.com/other/page)")
        expect(refusals).to be_empty
      end
    end

    it "scrubs invalid bytes instead of raising, once, at the top" do
      raw = "\xFF @alice `x`".dup.force_encoding(Encoding::UTF_8)
      output = extract(raw)

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to start_with("� ")
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "records the destination span so resolution never touches a title" do
      extract(
        %{[docs](https://forum.example.com/t/slug/5 "see https://forum.example.com/t/slug/5") `x`},
      )

      row = buffer.links.first
      # The span points at the destination; the same URL inside the title is
      # outside it, so the importer's span rewrite cannot reach it.
      expect(row[:url_offset]).to eq("[docs](".bytesize)
      expect(row[:label_url_offset]).to be_nil
    end

    it "records the label span of a self-link" do
      extract("[https://forum.example.com/t/slug/5](https://forum.example.com/t/slug/5) `x`")

      row = buffer.links.first
      expect(row[:label_url_offset]).to eq(1)
      expect(row[:url_offset]).to eq("[https://forum.example.com/t/slug/5](".bytesize)
    end

    it "costs a per-input engine failure one body, not the conversion" do
      failing_engine = instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(failing_engine).to receive(:scan).and_raise(
        MiniRacer::ScriptTerminatedError,
        "JavaScript was terminated",
      )
      details = []
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: failing_engine,
          on_engine_refusal:
            lambda do |cause, detail|
              refusals << cause
              details << detail
            end,
        )

      raw = "@alice `x`"
      expect(extractor.extract(raw)).to eq(raw)
      expect(refusals).to eq(%i[engine_error])
      expect(details).to eq(%w[MiniRacer::ScriptTerminatedError])
      # The failed fast attempt plus the failed slow retry, each followed by a
      # context reset so the next body gets a healthy engine.
      expect(failing_engine).to have_received(:scan).twice
      expect(failing_engine).to have_received(:reset!).twice
      expect(extractor.slow_parses).to eq(0)
    end

    it "recovers a body whose parse only succeeds on the slow retry" do
      ceilings = []
      retrying_engine =
        instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(retrying_engine).to receive(:scan) do |posts, timeout_ms: nil|
        ceilings << timeout_ms
        raise MiniRacer::ScriptTerminatedError, "terminated" if ceilings.size == 1
        markdown_engine.scan(posts)
      end
      slow_parses_seen = 0
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: retrying_engine,
          on_engine_refusal: ->(cause, _detail) { refusals << cause },
          on_slow_parse: -> { slow_parses_seen += 1 },
        )

      output = extractor.extract("@alice `x`")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
      expect(refusals).to be_empty
      # The fast attempt carries no override; the retry carries the ceiling.
      expect(ceilings).to eq(
        [nil, Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::SLOW_TIMEOUT_MS],
      )
      expect(retrying_engine).to have_received(:reset!).once
      expect(extractor.slow_parses).to eq(1)
      expect(slow_parses_seen).to eq(1)
    end

    it "refuses directly when the slow retry is disabled" do
      failing_engine = instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(failing_engine).to receive(:scan).and_raise(
        MiniRacer::ScriptTerminatedError,
        "terminated",
      )
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: failing_engine,
          slow_timeout_ms: nil,
          on_engine_refusal: ->(cause, _detail) { refusals << cause },
        )

      expect(extractor.extract("@alice `x`")).to eq("@alice `x`")
      expect(refusals).to eq(%i[engine_error])
      expect(failing_engine).to have_received(:scan).once
    end

    it "runs a slow-path body's substitution checks under the scaled budget" do
      engine_scanner = Migrations::Converters::Discourse::MarkdownScanner::EngineScanner
      allow(engine_scanner::SubstitutionPass).to receive(:new).and_call_original
      calls = 0
      retrying_engine =
        instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(retrying_engine).to receive(:scan) do |posts, timeout_ms: nil|
        calls += 1
        raise MiniRacer::ScriptTerminatedError, "terminated" if calls == 1
        markdown_engine.scan(posts)
      end
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: retrying_engine,
          on_engine_refusal: ->(cause, _detail) { refusals << cause },
        )

      # Count matching cannot split this pair, so the body needs its check —
      # which must run with the slow ceiling's budget: the default budget is
      # smaller than what a single legitimate slow parse may already take.
      output = extractor.extract("`@alice` and @alice")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to eq("`@alice` and #{buffer.mentions.first[:placeholder]}")
      expect(refusals).to be_empty
      expect(extractor.slow_parses).to eq(1)
      expect(engine_scanner::SubstitutionPass).to have_received(:new).with(
        anything,
        anything,
        anything,
        anything,
        seconds_budget: engine_scanner::SLOW_TIMEOUT_MS / 1000.0,
      )
    end
  end

  describe "batched scan data" do
    let(:body) { "@alice wrote `@bob` and [docs](https://forum.example.com/t/slug/5)" }

    it "classifies bodies for a batching caller" do
      expect(extractor.engine_bound?(body)).to be(true)
      expect(extractor.engine_bound?("plain text, nothing to find")).to be(false)
      expect(extractor.engine_bound?(nil)).to be(false)
    end

    it "extracts from a precomputed engine scan like from a live one" do
      scan_data = markdown_engine.scan([{ id: 1, raw: body }]).first
      output = extractor.extract(body, scan_data:)

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(buffer.links.map { |row| row[:target_id] }).to eq([5])
      expect(output).to include("`@bob`")
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "ignores scan data when normalization changed the body's bytes" do
      invalid = (+"\xFF @alice").force_encoding(Encoding::UTF_8)
      # Scan data computed from any bytes; normalization rewrites the body, so
      # the extractor must scan live instead of trusting mismatched offsets.
      scan_data = markdown_engine.scan([{ id: 1, raw: invalid }]).first

      output = extractor.extract(invalid, scan_data:)

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "scans a batch in one call, keyed by post id" do
      data = extractor.scan_batch([{ id: 7, raw: body }, { id: 9, raw: "plain @alice" }])

      expect(data.keys).to contain_exactly(7, 9)
      output = extractor.extract(body, scan_data: data[7])
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "returns no data when the batched call is terminated, and per-body extraction recovers" do
      # One pathological body terminates the whole batched V8 call; the
      # contract is that the batch yields nothing and every body falls back to
      # the normal per-body ladder — which must find a healthy engine.
      flaky_engine = instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(flaky_engine).to receive(:scan) do |posts, timeout_ms: nil|
        raise MiniRacer::ScriptTerminatedError if posts.size > 1
        markdown_engine.scan(posts, timeout_ms:)
      end
      batching_extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          custom_emoji_names:,
          internal_link_hosts:,
          markdown_engine: flaky_engine,
        )

      data = batching_extractor.scan_batch([{ id: 7, raw: body }, { id: 9, raw: "hi @alice" }])

      expect(data).to eq({})
      expect(flaky_engine).to have_received(:reset!)
      output = batching_extractor.extract(body, scan_data: data[7])
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
    end
  end
end
