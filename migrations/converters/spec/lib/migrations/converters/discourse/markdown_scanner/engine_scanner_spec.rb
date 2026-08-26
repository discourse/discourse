# frozen_string_literal: true

# The engine tier end to end: RawExtractor with a real MarkdownEngine::Context,
# so the constructs come out of the actual discourse-markdown-it parse and the
# positions out of count certification. The engine context needs no Rails, so
# this runs in the isolated suite.
RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  let(:custom_emoji_names) { %w[parrot] }
  let(:category_slugs) { %w[support] }
  let(:tag_names) { %w[release] }
  let(:internal_link_hosts) { { "forum.example.com" => nil } }
  let(:refusals) { [] }

  let(:engine) do
    Migrations::Converters::MarkdownEngine::Context.new(
      bundle: Migrations::Converters::MarkdownEngine::Bundle.load_or_build,
      config:
        Migrations::Converters::MarkdownEngine::Config.new(
          source_settings: {
            "unicode_usernames" => true,
          },
          category_slugs:,
          tag_names:,
          custom_emoji_names:,
        ),
    )
  end

  let(:extractor) do
    described_class.new(
      embeds: buffer,
      mention_names:,
      hashtag_names:,
      custom_emoji_names:,
      internal_link_hosts:,
      markdown_engine: engine,
      on_engine_refusal: ->(cause) { refusals << cause },
    )
  end

  after { engine.close }

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

    it "refuses when the same name sits ambiguously in one block" do
      raw = "`@alice` and @alice"
      output = extract(raw)

      expect(output).to eq(raw)
      expect(buffer.mentions).to be_empty
      expect(refusals).to eq(%i[count_mismatch])
      expect(extractor.engine_refusals).to eq(count_mismatch: 1)
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

    it "leaves a link form no detector grammar takes verbatim without refusing the body" do
      # CommonMark allows an escaped `]` inside a label; the detector grammar
      # does not, so the certified destination cannot be anchored to a node.
      raw = "@alice sees [a \\] b](https://forum.example.com/t/slug/5) `y`"
      output = extract(raw)

      expect(buffer.links).to be_empty
      expect(buffer.mentions.map { |row| row[:name] }).to eq(%w[alice])
      expect(output).to include("[a \\] b](https://forum.example.com/t/slug/5)")
      expect(refusals).to be_empty
    end

    it "leaves an external link untouched" do
      raw = "`x` [docs](https://elsewhere.example.org/page)"
      output = extract(raw)

      expect(output).to eq(raw)
      expect(buffer.links).to be_empty
      expect(refusals).to be_empty
    end

    it "refuses a body with a construct-capable entity near a construct" do
      raw = "@alice and &#64;bob `x`"
      output = extract(raw)

      expect(output).to eq(raw)
      expect(refusals).to eq(%i[entity])
    end

    it "refuses CR line endings" do
      raw = "@alice\r\nhello `x`"
      output = extract(raw)

      expect(output).to eq(raw)
      expect(refusals).to eq(%i[cr_line_endings])
    end
  end
end
