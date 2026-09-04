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
      prepared = extractor.prepare(raw: "[quote]\nquoted prose\n[/quote]")
      expect(prepared).not_to be_engine_bound
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

    it "refuses a recognized reference no grammar can take, instead of calling it handled" do
      # CommonMark allows an escaped `]` inside a label; the construct grammar
      # does not. An internal URL there is still rewritten as the destination it
      # is, but an `upload://` one carries its alt text and dimensions in the
      # syntax around it, so a destination-only rewrite would lose them. The
      # reference is real and stays stale — that must land on the must-resolve
      # tally, never report as success. The mention beside it is still
      # extracted.
      raw = "@alice sees [a \\] b](upload://#{sha1}.png) `y`"
      output = extract(raw)

      expect(buffer.uploads).to be_empty
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("[a \\] b](upload://#{sha1}.png)")
      expect(refusals).to eq(%i[unanchored])
    end

    it "rewrites the destination of a link whose label no grammar can take" do
      raw = "sees [a \\] b](https://forum.example.com/t/slug/5) `y`"
      output = extract(raw)

      expect(buffer.links.first).to include(
        url: "https://forum.example.com/t/slug/5",
        text: nil,
        original_markdown: "https://forum.example.com/t/slug/5",
        url_offset: 0,
      )
      expect(output).to eq("sees [a \\] b](#{buffer.links.first[:placeholder]}) `y`")
      expect(refusals).to be_empty
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

    # markdown-it strips a backslash escape before the text rules run, so core
    # cooks `\\@bob` as a mention. A counter that read the escape as a
    # rejection counted one occurrence too few here and handed the token to the
    # code-span look-alike — the post came back with its code span rewritten.
    [
      ["mention", "\\@bob", "`@bob`", :mentions, "bob"],
      ["hashtag", "\\#support", "`#support`", :hashtags, "support"],
      ["custom emoji", "\\:parrot:", "`:parrot:`", :emojis, "parrot"],
    ].each do |kind, escaped, shielded, rows, name|
      it "rewrites an escaped #{kind} and leaves the code-span copy alone" do
        output = extract("#{escaped} and #{shielded}")

        expect(buffer.public_send(rows).map { |row| row[:name] }).to eq([name])
        placeholder = buffer.public_send(rows).first[:placeholder]
        expect(output).to eq("\\#{placeholder} and #{shielded}")
        expect(refusals).to be_empty
      end
    end

    it "rewrites a shortcode the author upper-cased and leaves the code-span copy alone" do
      # Core lowercases a shortcode before it looks a custom emoji up, so
      # `:PARROT:` is the same emoji — and counting has to fold the raw the
      # same way, or the engine's one token lands on the code span.
      output = extract(":PARROT: and `:parrot:`")

      expect(buffer.emojis.map { |row| row[:name] }).to eq(%w[PARROT])
      expect(output).to eq("#{buffer.emojis.first[:placeholder]} and `:parrot:`")
      expect(refusals).to be_empty
    end

    it "records a shortcode in the author's own case" do
      output = extract("nice :ParRot: work")

      expect(buffer.emojis.map { |row| row[:name] }).to eq(%w[ParRot])
      expect(output).to eq("nice #{buffer.emojis.first[:placeholder]} work")
      expect(refusals).to be_empty
    end

    it "stores the raw spelling of a swallowed query, not the href's percent-encoding" do
      # Linkify takes the quote and everything after it into the href and
      # percent-encodes it there. The href may only resolve the host: the
      # suffix the importer writes back is read from the raw bytes, so the
      # author's spelling survives the origin rewrite.
      raw = %{key: https://forum.example.com/user-api-key/new?public_key="AAAAB3NzaC1yc2E" ok}
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first).to include(
        target_suffix: %{/user-api-key/new?public_key="AAAAB3NzaC1yc2E"},
        original_markdown:
          %{https://forum.example.com/user-api-key/new?public_key="AAAAB3NzaC1yc2E"},
      )
      expect(output).to eq("key: #{buffer.links.first[:placeholder]} ok")
      expect(refusals).to be_empty
    end

    it "stores a typed target's suffix in the raw spelling too" do
      # Linkify swallows a balanced quote pair into the href and encodes it;
      # the suffix stays in the author's spelling.
      raw = %{see https://forum.example.com/t/slug/5?q="abc" now}
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(buffer.links.first).to include(target_id: 5, target_suffix: %{?q="abc"})
      expect(output).to eq("see #{buffer.links.first[:placeholder]} now")
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
      # definition's reuse. A definition-bearing value never matches by
      # counting; the substitution checks confirm the definition (both
      # tokens vanish) and skip the code copy (nothing changes).
      raw =
        "see [a][1] and [b][1] and `https://forum.example.com/t/slug/5`\n\n" \
          "[1]: https://forum.example.com/t/slug/5\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(output).to include("`https://forum.example.com/t/slug/5`")
      expect(output).to include("[1]: #{buffer.links.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "rewrites a shared definition but not a definition-shaped line inside a fence" do
      # Two link tokens, two raw occurrences — the counts are equal, and the
      # fenced copy is even shaped like a definition. Equality must not
      # accept a definition-bearing value: only the substitution checks can
      # tell the live definition (both tokens vanish) from the fenced copy
      # (nothing changes).
      fenced_line = "[also]: https://forum.example.com/t/slug/5"
      raw =
        "see [a][1] and [b][1]\n\n" \
          "[1]: https://forum.example.com/t/slug/5\n\n" \
          "```text\n#{fenced_line}\n```\n"
      output = extract(raw)

      expect(buffer.links.size).to eq(1)
      expect(output).to include(fenced_line)
      expect(output).to include("[1]: #{buffer.links.first[:placeholder]}")
      expect(refusals).to be_empty
    end

    it "refuses a body with more distinct tracked URLs than the value cap" do
      count =
        Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::MAX_SCANNED_VALUES + 1
      raw = (1..count).map { |i| "https://forum.example.com/t/s/#{i}" }.join(" ")
      output = extract(raw)

      expect(output).to eq(raw)
      expect(buffer.links).to be_empty
      expect(refusals).to eq(%i[url_volume])
    end

    it "extracts both mentions when one name is a prefix of the other" do
      # `@bob` occurs twice in the raw — once on its own, once inside `@bobby` —
      # against the engine's one token, so counting escalates. Substitution
      # then confirms the standalone one and rejects the spelling inside the
      # longer name, which is what keeps both mentions and their spans right.
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:
            Migrations::CompactStringSet.new(
              %w[bob bobby].map { |name| Migrations::NameNormalizer.normalize(name) },
            ),
          hashtag_names:,
          markdown_engine:,
          on_engine_refusal:,
        )

      output = extractor.extract("@bob and @bobby")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[bob bobby])
      placeholders = buffer.mentions.map { |row| row[:placeholder] }
      expect(output).to eq("#{placeholders[0]} and #{placeholders[1]}")
      expect(refusals).to be_empty
    end

    it "refuses a body with more distinct tracked names than the value cap" do
      # Locating a name costs one scan of the body, exactly as a URL does.
      count =
        Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::MAX_SCANNED_VALUES + 1
      names = (1..count).map { |i| format("user%04d", i) }
      raw = names.map { |name| "@#{name}" }.join(" ")
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:
            Migrations::CompactStringSet.new(
              names.map { |name| Migrations::NameNormalizer.normalize(name) },
            ),
          hashtag_names:,
          markdown_engine:,
          on_engine_refusal:,
        )

      expect(extractor.extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
      expect(refusals).to eq(%i[name_volume])
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

    it "stops enumerating a repeated value's occurrences at the substitution limit" do
      engine_calls = 0
      counting_engine =
        instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(counting_engine).to receive(:scan) do |posts, timeout_ms: nil|
        engine_calls += 1
        markdown_engine.scan(posts)
      end
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: counting_engine,
          on_engine_refusal:,
        )
      max =
        Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::SubstitutionPass::MAX_SUBSTITUTIONS

      # 200 live mentions plus one code-span copy: counting refuses the body,
      # and the substitution pass pays at most the limit — the code-span copy
      # burns the first check, the confirmed tail ends at the limit.
      output = extractor.extract("`@alice` #{(["@alice"] * 200).join(" ")}")

      # One initial parse, then one parse per check up to the limit; the
      # occurrences past the limit cost no engine call.
      expect(engine_calls).to eq(1 + max)
      expect(buffer.mentions.size).to eq(max - 1)
      expect(output).to start_with("`@alice` ")
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
          on_engine_refusal:,
          on_slow_parse: -> { slow_parses_seen += 1 },
        )

      output = extractor.extract("@alice `x`")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
      expect(refusals).to be_empty
      # The fast attempt carries no override; the retry's ceiling is the time
      # left until the per-body deadline, computed just after the deadline is
      # set, so it comes in at most a moment under the constant.
      slow_ms = Migrations::Converters::Discourse::MarkdownScanner::EngineScanner::SLOW_TIMEOUT_MS
      expect(ceilings.size).to eq(2)
      expect(ceilings.first).to be_nil
      expect(ceilings.last).to be_between(slow_ms - 1_000, slow_ms)
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
          on_engine_refusal:,
        )

      expect(extractor.extract("@alice `x`")).to eq("@alice `x`")
      expect(refusals).to eq(%i[engine_error])
      expect(failing_engine).to have_received(:scan).once
    end

    it "runs a slow-path body's substitution checks under what is left of the retry deadline" do
      engine_scanner = Migrations::Converters::Discourse::MarkdownScanner::EngineScanner
      budgets = []
      allow(engine_scanner::SubstitutionPass).to receive(
        :new,
      ).and_wrap_original do |original, *args, **kwargs|
        budgets << kwargs[:seconds_budget]
        original.call(*args, **kwargs)
      end
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
          on_engine_refusal:,
        )

      # Count matching cannot split this pair, so the body needs its check —
      # which must run with more than the default budget (a single legitimate
      # slow parse may already take longer than that), but only with what the
      # slow parse left of the 30-second retry deadline, never a fresh
      # 30 seconds on top of it.
      output = extractor.extract("`@alice` and @alice")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to eq("`@alice` and #{buffer.mentions.first[:placeholder]}")
      expect(refusals).to be_empty
      expect(extractor.slow_parses).to eq(1)
      slow_ceiling = engine_scanner::SLOW_TIMEOUT_MS / 1000.0
      expect(budgets).to all(be > engine_scanner::SubstitutionPass::SUBSTITUTION_SECONDS_BUDGET)
      expect(budgets).to all(be < slow_ceiling)
    end

    it "shrinks every engine call's ceiling toward the deadline and stops at zero" do
      # A scripted clock: each engine call costs seven scripted seconds, so
      # the deadline runs out in the middle of the substitution checks.
      now = 0.0
      allow(Process).to receive(:clock_gettime).and_call_original
      allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC) { now }
      ceilings = []
      calls = 0
      slow_engine = instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(slow_engine).to receive(:scan) do |posts, timeout_ms: nil|
        ceilings << timeout_ms
        calls += 1
        now += 7.0
        raise MiniRacer::ScriptTerminatedError, "terminated" if calls == 1
        markdown_engine.scan(posts)
      end
      extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          markdown_engine: slow_engine,
          on_engine_refusal:,
        )

      # One copy in code and five in prose: counts cannot match, so every
      # occurrence needs its own substitution parse — more parses than the
      # deadline has time for.
      output = extractor.extract("`@alice` and @alice and @alice and @alice and @alice and @alice")

      # The fast attempt has no ceiling; the retry's base parse gets the full
      # deadline; each substitution parse gets exactly the time left until
      # the deadline, so no call can run past it, and a call with no time
      # left is declined.
      expect(ceilings).to eq([nil, 30_000, 23_000, 16_000, 9_000, 2_000])
      expect(refusals).to eq(%i[substitution_budget])
      # The code copy was checked first and found to be no construct; three
      # prose occurrences were confirmed before the deadline ran out, the
      # other two stay as written.
      expect(output).to include("`@alice`")
      expect(buffer.mentions.size).to eq(3)
      expect(output.scan("@alice").size).to eq(3)
    end
  end

  describe "prepared batch scanning" do
    let(:body) { "@alice wrote `@bob` and [docs](https://forum.example.com/t/slug/5)" }

    it "normalizes and classifies a body once for a batching caller" do
      invalid = (+"\xFF @alice").force_encoding(Encoding::UTF_8)

      candidate = extractor.prepare(id: 1, raw: invalid, topic_id: 4)
      plain = extractor.prepare(id: 2, raw: "plain text, nothing to find")
      empty = extractor.prepare(id: 3, raw: nil)

      expect(candidate.raw).to be_valid_encoding
      expect(candidate.raw).to eq("� @alice")
      expect(candidate.topic_id).to eq(4)
      expect(candidate).to be_engine_bound
      expect(plain).not_to be_engine_bound
      expect(empty).not_to be_engine_bound
    end

    it "extracts prepared bytes with their precomputed scan data" do
      prepared = extractor.prepare(id: 1, raw: body)
      scan_data = extractor.scan_batches([prepared])
      output = extractor.extract_prepared(prepared, scan_data: scan_data[1])

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(buffer.links.map { |row| row[:target_id] }).to eq([5])
      expect(output).to include("`@bob`")
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "scans and extracts the same normalized bytes" do
      invalid = (+"\xFF @alice").force_encoding(Encoding::UTF_8)
      prepared = extractor.prepare(id: 1, raw: invalid)
      scan_data = extractor.scan_batches([prepared])

      output = extractor.extract_prepared(prepared, scan_data: scan_data[1])

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to start_with("� ")
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "returns scan data keyed by id and omits bodies that do not need the engine" do
      candidate = extractor.prepare(id: 7, raw: body)
      plain = extractor.prepare(id: 9, raw: "plain text")
      data = extractor.scan_batches([candidate, plain])

      expect(data.keys).to contain_exactly(7)
      output = extractor.extract_prepared(candidate, scan_data: data[7])
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
    end

    it "rejects engine-bound bodies with duplicate ids" do
      first = extractor.prepare(id: 7, raw: body)
      second = extractor.prepare(id: 7, raw: "hi @alice")

      # Keying by id would silently keep only one of the results.
      expect { extractor.scan_batches([first, second]) }.to raise_error(ArgumentError, /unique ids/)
    end

    it "bounds each engine call by post count and aggregate bytes" do
      bounded_engine = instance_double(Migrations::Converters::MarkdownEngine::Context)
      allow(bounded_engine).to receive(:scan) do |posts, timeout_ms: nil|
        raise "oversized scan" if posts.size > 2 || posts.sum { |post| post[:raw].bytesize } > 80

        markdown_engine.scan(posts, timeout_ms:)
      end
      allow(bounded_engine).to receive(:reset!)
      batching_extractor =
        described_class.new(
          embeds: buffer,
          mention_names:,
          hashtag_names:,
          custom_emoji_names:,
          internal_link_hosts:,
          markdown_engine: bounded_engine,
        )
      prepared = [
        batching_extractor.prepare(id: 7, raw: body),
        batching_extractor.prepare(id: 8, raw: "hi @alice"),
        batching_extractor.prepare(id: 9, raw: "bye @alice"),
        batching_extractor.prepare(id: 10, raw: "cc @alice"),
      ]

      data = batching_extractor.scan_batches(prepared, max_posts: 2, max_bytes: 80)

      expect(data.keys).to contain_exactly(7, 8, 9, 10)
    end

    it "scans a single body that exceeds the batch byte target" do
      prepared = extractor.prepare(id: 7, raw: "@alice #{"x" * 100}")

      data = extractor.scan_batches([prepared], max_bytes: 10)

      expect(data.keys).to contain_exactly(7)
    end

    it "keeps successful partitions when another partition terminates" do
      flaky_engine = instance_double(Migrations::Converters::MarkdownEngine::Context, reset!: nil)
      allow(flaky_engine).to receive(:scan) do |posts, timeout_ms: nil|
        raise MiniRacer::ScriptTerminatedError if posts.any? { |post| post[:id] == 7 }

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

      failed = batching_extractor.prepare(id: 7, raw: body)
      successful = batching_extractor.prepare(id: 9, raw: "hi @alice")
      data = batching_extractor.scan_batches([failed, successful], max_posts: 1)

      expect(data.keys).to contain_exactly(9)
      expect(flaky_engine).to have_received(:reset!)
      output = batching_extractor.extract_prepared(failed, scan_data: data[7])
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include(buffer.mentions.first[:placeholder])
    end
  end

  describe "plugin syntax shielding" do
    context "with the plugin settings enabled on the source" do
      # A source with these plugins enabled parses their blocks with the real
      # plugin rules, so candidate text inside plugin syntax is not prose and
      # must stay as written; the same text in prose beside it is extracted.
      let(:markdown_engine) do
        MarkdownEngineHelper.context_for(
          settings: {
            "unicode_usernames" => true,
            "discourse_events_enabled" => true,
            "discourse_post_event_enabled" => true,
            "discourse_graphviz_enabled" => true,
            "discourse_math_enabled" => true,
            "policy_enabled" => true,
          },
        )
      end

      it "keeps a mention inside an event header and extracts the prose copy" do
        raw = %{[event name="@alice" start="2026-01-01"]\n[/event]\n\nthanks @alice}
        output = extract(raw)

        expect(refusals).to be_empty
        expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
        expect(output).to include(%{[event name="@alice" start="2026-01-01"]})
        expect(output).to end_with("thanks #{buffer.mentions.first[:placeholder]}")
      end

      it "keeps a mention inside a math block" do
        output = extract("$$\n@alice + x\n$$\n\n@alice")

        expect(refusals).to be_empty
        expect(buffer.mentions.size).to eq(1)
        expect(output).to include("$$\n@alice + x\n$$")
        expect(output).to end_with(buffer.mentions.first[:placeholder])
      end

      it "keeps a mention inside a graphviz program" do
        output = extract("[graphviz]\n@alice -> x\n[/graphviz]\n\n@alice")

        expect(refusals).to be_empty
        expect(buffer.mentions.size).to eq(1)
        expect(output).to include("[graphviz]\n@alice -> x\n[/graphviz]")
        expect(output).to end_with(buffer.mentions.first[:placeholder])
      end

      it "keeps a mention inside a policy header while its body stays prose" do
        raw = %{[policy group="@alice"]\nplease agree, @alice\n[/policy]}
        output = extract(raw)

        expect(refusals).to be_empty
        expect(buffer.mentions.size).to eq(1)
        expect(output).to include(%{[policy group="@alice"]})
        expect(output).to include("please agree, #{buffer.mentions.first[:placeholder]}")
      end
    end

    it "treats plugin syntax as prose when the source did not enable the plugin" do
      # The default engine runs without these plugin settings, so `$$` is
      # ordinary text there and the mention in between is a real mention —
      # exactly what such a post cooks to on a site without the plugin.
      output = extractor.extract("$$ @alice $$")

      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to eq("$$ #{buffer.mentions.first[:placeholder]} $$")
    end
  end
end
