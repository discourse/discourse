# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::RawExtractor do
  include_context "with raw extractor"

  it "returns nil for a nil body" do
    expect(extract(nil)).to be_nil
  end

  it "leaves a body with no embeds untouched" do
    raw = "Just some **plain** text with a (paren) and a / slash."

    expect(extract(raw)).to eq(raw)
    expect(buffer).to be_empty
  end

  # The whole reason to wrap Markbridge's scanner: things that only look like
  # embeds inside code must be left alone.
  describe "code blocks" do
    it "does not extract from a fenced code block" do
      raw = <<~MD
        real @alice here

        ```
        not a @mention and ![x](upload://nope.png) and [quote="ghost"]q[/quote]
        ```
      MD

      result = extract(raw)

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(buffer.uploads).to be_empty
      expect(buffer.quotes).to be_empty
      expect(result).to include("not a @mention and ![x](upload://nope.png)")
    end

    it "does not extract from inline code" do
      result = extract("use `@channel` carefully, @alice")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
      expect(result).to include("`@channel`")
    end
  end

  # An indented code block is only recognized where the line before it settles it:
  # a blank line, and before that a line that is neither a list item nor itself
  # indented. Inside a list the threshold is the item's content indent plus four,
  # which would need real block parsing, so those lines stay ordinary content —
  # extracting from something meant as code only rewrites text, while treating
  # content as code drops the upload entirely. Checked against PrettyText.
  describe "indented code blocks" do
    let(:upload) { "![shot](upload://abc.png)" }

    it "does not extract from an indented block after a blank line" do
      raw = "Intro\n\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from an indented block at the start of the input" do
      raw = "    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from an indented block after a heading" do
      raw = "# Title\n\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from a tab-indented block" do
      raw = "Intro\n\n\t#{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "reopens a block after an unindented line interrupts it" do
      raw = "Intro\n\n    a\ntext\n\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    # An indented line straight after a paragraph line is a lazy continuation, so
    # core renders the image rather than a code block.
    it "extracts from an indent that cannot interrupt a paragraph" do
      extract("Intro line\n    #{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    it "extracts from an indent under a bullet" do
      extract("- item\n    #{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    # Four spaces against a numbered item's content indent of three is one past
    # it, not four, so this renders as the list item's image in core. An indented
    # screenshot under a numbered step is ordinary post formatting.
    it "extracts from an indent under a numbered step" do
      extract("1. Step one\n\n    #{upload}\n\n2. Step two\n")

      expect(buffer.uploads.size).to eq(1)
    end

    it "extracts from a deeper indent inside a list, where the threshold is unknown" do
      extract("- item\n\n      #{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    it "recognizes a block again once the list has ended" do
      raw = "- item\n\ntext\n\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end
  end

  # An unpaired backtick is literal text in CommonMark, so it must not open a code
  # span that swallows the rest of the post. A span exists only when a matching
  # closer follows within the same paragraph. Every expectation here was checked
  # against PrettyText.
  describe "inline code spans" do
    let(:hashtag_names) do
      Migrations::SortedStringSet.new([Migrations::NameNormalizer.normalize("general")])
    end
    let(:hashtag_extractor) { described_class.new(embeds: buffer, hashtag_names:) }
    let(:emoji_extractor) { described_class.new(embeds: buffer, custom_emoji_names: %w[parrot]) }

    it "extracts a mention after an unpaired backtick" do
      extract("a`@alice here")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
    end

    it "extracts a hashtag after an unpaired backtick" do
      hashtag_extractor.extract("a`#general here")

      expect(buffer.hashtags.map { |h| h[:name] }).to eq(%w[general])
    end

    it "extracts a custom emoji after an unpaired backtick" do
      emoji_extractor.extract("a`:parrot: here")

      expect(buffer.emojis.map { |e| e[:name] }).to eq(%w[parrot])
    end

    it "suppresses a mention inside a paired span" do
      result = extract("`@alice` here")

      expect(buffer.mentions).to be_empty
      expect(result).to eq("`@alice` here")
    end

    it "suppresses a mention in a span that crosses a single newline" do
      result = extract("`a\n@alice` here")

      expect(buffer.mentions).to be_empty
      expect(result).to eq("`a\n@alice` here")
    end

    it "treats both halves as literal when a blank line splits the backticks" do
      result = extract("`@alice\n\n@bob` here")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice bob])
      expect(result).to include("`", "`")
    end

    it "keeps an embedded single backtick inside a double-backtick span as code" do
      result = extract("``a`@alice`` here")

      expect(buffer.mentions).to be_empty
      expect(result).to eq("``a`@alice`` here")
    end

    it "keeps detecting after a double run that finds no matching closer" do
      # ``@alice` — the `` opens no span (no `` closer follows), so it is literal
      # and the mention after it is extracted.
      extract("``@alice`")

      expect(buffer.mentions.map { |m| m[:name] }).to eq(%w[alice])
    end
  end

  it "raises on a node type it has no defer handler for" do
    # `extract` builds its detectors internally and never produces an unknown
    # node, so this guard is unreachable through the public API; open up the
    # private method deliberately to exercise it.
    seam = Class.new(described_class) { public :defer }.new(embeds: buffer)

    expect { seam.defer(Object.new) }.to raise_error(NotImplementedError, /Object/)
  end

  # The contract: every token spliced into the result maps to exactly one recorded
  # linkage descriptor.
  it "keeps placeholders and linkage rows one-to-one" do
    result =
      extract(
        "intro @carol see ![pic](upload://h45h.png) and\n" \
          "[quote=\"dan, post:9, topic:3\"]\nq\n[/quote] done",
      )

    expect(Migrations::Placeholder.scan(result)).to match_array(buffer.placeholders)
  end

  describe "Unicode raw" do
    it "leaves a body of only Unicode text untouched" do
      raw = "これは 🎉 café テスト — nothing to extract"

      expect(extract(raw)).to eq(raw)
      expect(buffer).to be_empty
    end

    it "captures a whole Unicode username, not just its ASCII prefix" do
      extract("cc @café_team here")

      expect(buffer.mentions.first[:name]).to eq("café_team")
    end

    it "captures a username with a combining mark (decomposed form)" do
      name = "José".unicode_normalize(:nfd)
      extract("ping @#{name} thanks")

      captured = buffer.mentions.first[:name]
      expect(captured.unicode_normalize).to eq("José".unicode_normalize)
    end

    it "captures a CJK username" do
      extract("hi @田中 there")

      expect(buffer.mentions.first[:name]).to eq("田中")
    end

    it "does not treat @name after a Unicode letter as a mention" do
      raw = "café@john"

      expect(extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    it "preserves Unicode around an extracted embed and stays valid encoding" do
      result = extract("日本語 ![絵](upload://abc.png) 🎉")

      expect(buffer.uploads.size).to eq(1)
      expect(result).to eq("日本語 #{buffer.uploads.first[:placeholder]} 🎉")
      expect(result).to be_valid_encoding
    end

    it "does not extract embeds from a code block that contains Unicode" do
      raw = "```\n@josé [quote=\"x, post:1\"] 日本\n```\n@real"
      result = extract(raw)

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[real])
      expect(result).to include("@josé", '[quote="x, post:1"]', "日本")
    end

    # Multibyte text BEFORE a construct shifts every later byte offset away from
    # its character offset, so any byte-indexed look-back reads the wrong byte.
    # These bodies are shaped so that wrong byte is an alphanumeric — a boundary
    # check that mixes up the two index kinds rejects the construct.
    context "with multibyte text before the construct" do
      it "still defers a mention" do
        result = extract("héllo @alice hi")

        expect(buffer.mentions.first[:name]).to eq("alice")
        expect(result).to eq("héllo #{buffer.mentions.first[:placeholder]} hi")
      end

      it "still defers a hashtag" do
        extract("höhe #support da")

        expect(buffer.hashtags.first[:name]).to eq("support")
      end

      it "still defers a bare internal link" do
        # An absolute bare URL still detects in prose, so it exercises the
        # byte-offset look-back with multibyte text before it.
        host_extractor =
          described_class.new(embeds: buffer, internal_link_hosts: { "forum.example.com" => nil })
        host_extractor.extract("Höhe https://forum.example.com/t/thema/9 an")

        expect(buffer.links.first).to include(target_id: 9)
      end

      it "still defers a custom emoji" do
        emoji_extractor = described_class.new(embeds: buffer, custom_emoji_names: %w[parrot])
        emoji_extractor.extract("schön :parrot:")

        expect(buffer.emojis.first[:name]).to eq("parrot")
      end

      it "still keeps a glued mention literal" do
        raw = "das naïve@alice bleibt"

        expect(extract(raw)).to eq(raw)
        expect(buffer.mentions).to be_empty
      end
    end
  end
end
