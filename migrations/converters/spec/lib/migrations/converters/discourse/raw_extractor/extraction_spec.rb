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

    # Inline code spans are covered from the count-matching angle in
    # engine_scanner_spec, placeholder positions included.
  end

  # Indented code opens wherever no paragraph is open and the line reaches four
  # columns past its container's content column — under a bullet that is six
  # columns, under `1.` seven. An indented line inside an open paragraph is a lazy
  # continuation instead. Checked against PrettyText.
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

    # Nothing needs a blank line before it: a heading is a leaf block that closes
    # itself, so the next line opens code straight away.
    it "does not extract from an indented block right under a heading" do
      raw = "# Title\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from an indented block right after a closed fence" do
      raw = "```\nx\n```\n    #{upload}\n"

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

    # Six columns is the bullet's content indent of two plus four, so core does
    # render this one as code.
    it "does not extract from a deeper indent inside a list" do
      raw = "- item\n\n      #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from a tab-indented block inside a list" do
      raw = "-\titem\n\n\t\t#{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from an indented block inside a blockquote" do
      raw = "> Intro\n>\n>     #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "recognizes a block again once the list has ended" do
      raw = "- item\n\ntext\n\n    #{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end
  end

  # `[code]` is a bbcode tag core renders as code in two shapes: a block, when the
  # opener stands alone on its line and a `[/code]` line closes it, and an inline
  # span otherwise. Every expectation here was checked against PrettyText.
  describe "[code] tags" do
    let(:upload) { "![shot](upload://abc.png)" }

    it "does not extract from a [code] block" do
      raw = "[code]\n#{upload}\n[/code]\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from a [code=lang] block" do
      raw = "[code=ruby]\n#{upload}\n[/code]\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from an inline [code] span" do
      raw = "see [code]#{upload}[/code] there"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    # The block form declines a closer that does not fill its line, and the inline
    # form — which is bounded by the paragraph, not the line — takes over.
    it "does not extract from a span whose closer has text after it" do
      raw = "[code]\n#{upload}\n[/code] x\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from a [code] block inside a blockquote" do
      raw = "> [code]\n> #{upload}\n> [/code]\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "extracts from an unclosed [code], which core leaves as prose" do
      extract("[code]\n#{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    it "extracts after a [code] block has closed" do
      extract("[code]\nx\n[/code]\n\n#{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    # A `[` that a construct claims never reaches the bbcode check, mirroring
    # markdown-it running the link rule before the inline bbcode rule.
    it "extracts from a link whose label happens to be code" do
      extract("z [code](https://external.com/x) #{upload} y[/code]")

      expect(buffer.uploads.size).to eq(1)
    end
  end

  # A `<pre>` at the start of a line is an HTML block, and everything through the
  # line holding `</pre>` is raw HTML. Checked against PrettyText.
  describe "<pre> blocks" do
    let(:upload) { "![shot](upload://abc.png)" }

    it "does not extract from a <pre> block" do
      raw = "<pre>\n#{upload}\n</pre>\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "does not extract from a one-line <pre>" do
      raw = "<pre>#{upload}</pre>\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    # Core's HTML block runs to the end of the input when it is never closed, so
    # the rest of the post is code too.
    it "does not extract from an unclosed <pre>" do
      raw = "<pre>\n#{upload}\n"

      expect(extract(raw)).to eq(raw)
      expect(buffer.uploads).to be_empty
    end

    it "extracts after a <pre> block has closed" do
      extract("<pre>\nx\n</pre>\n\n#{upload}\n")

      expect(buffer.uploads.size).to eq(1)
    end

    # Mid-line it is inline HTML, not a block, so core cooks what is inside it.
    it "extracts from a <pre> in the middle of a line" do
      extract("x <pre>#{upload}</pre> y")

      expect(buffer.uploads.size).to eq(1)
    end
  end

  # Core runs mentions, hashtags and emoji through the text-post-process engine,
  # which skips any text token inside a link — and a link's destination is not a
  # text token at all. So nothing is detected inside a link, and a `@name` there
  # stays somebody else's URL instead of being rewritten to a destination
  # username. Every expectation here was checked against PrettyText.
  describe "links" do
    let(:hashtag_names) do
      Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("general")])
    end
    let(:internal_link_hosts) { { source_host => nil } }
    let(:link_extractor) { extractor }

    [
      "[link](https://external.com/@bob)",
      "see https://external.com/x/@bob now",
      "<https://external.com/@bob>",
      "https://external.com/?a=1&t=@bob",
      "[hi @bob](https://external.com/)",
      "![alt @bob](https://external.com/p.png)",
      "//external.com/@bob",
      # `_` is a linkify boundary, so core links this one too.
      "x_https://external.com/@bob",
    ].each do |raw|
      it "leaves a mention inside #{raw} alone" do
        expect(link_extractor.extract(raw)).to eq(raw)
        expect(buffer.mentions).to be_empty
      end
    end

    it "leaves a hashtag inside a link alone" do
      raw = "see https://external.com/x/#general now"

      expect(link_extractor.extract(raw)).to eq(raw)
      expect(buffer.hashtags).to be_empty
    end

    # A destination may be followed by a title, and padded, and wrapped in angle
    # brackets. Core cooks all of these as links, so nothing inside them counts.
    [
      %([x](https://external.com/@bob "title")),
      "[x](https://external.com/@bob 'title')",
      "[x](https://external.com/@bob (title))",
      %([x](<https://external.com/@bob> "title")),
      "[x](https://external.com/@bob   )",
      "[x](   https://external.com/@bob   )",
      %([x](https://external.com/@bob\n"title")),
      %(![a](https://external.com/@bob/p.png "t")),
      # The title itself is an attribute, never text.
      %([x](/some/path "@bob title")),
      # Malformed enough that core builds no markdown link — but then linkify
      # takes the destination, so the mention is still inside a link.
      %([x](https://external.com/@bob "unclosed)),
      %([x](https://external.com/@bob extra "t")),
    ].each do |raw|
      it "leaves a mention alone in #{raw.inspect}" do
        expect(link_extractor.extract(raw)).to eq(raw)
        expect(buffer.mentions).to be_empty
      end
    end

    # Core builds no link here and does not linkify anything, so the mention is
    # ordinary text and must still be deferred.
    it "still defers a mention in parentheses that are not a link" do
      link_extractor.extract("[x](not a link @bob)")

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[bob])
    end

    it "still defers a mention in prose next to a link" do
      link_extractor.extract("hi @bob see https://external.com/@carol now")

      expect(buffer.mentions.map { |mention| mention[:name] }).to eq(%w[bob])
    end

    # The skip must not swallow a link another construct wants, or the embed it
    # carries would go unrecorded.
    it "still defers an internal link" do
      link_extractor.extract("[t](https://forum.example.com/t/slug/5)")

      expect(buffer.links.size).to eq(1)
    end

    it "still defers an upload inside a link" do
      link_extractor.extract("[f](https://cdn.example.com/uploads/default/original/1X/#{sha1}.png)")

      expect(buffer.uploads.size).to eq(1)
    end

    # The outer bracket must not match, or the walk would never reach the inner
    # image and the upload would be lost.
    it "still defers the inner image of a linked image on a foreign host" do
      link_extractor.extract("[![alt](upload://abc.png)](https://external.com/@bob)")

      expect(buffer.uploads.size).to eq(1)
      expect(buffer.mentions).to be_empty
    end

    # A `@name` in a relative destination is inside a link just like an
    # absolute one; a placeholder spliced into the URL would corrupt it.
    it "leaves a mention alone in a nested-text link's relative destination" do
      raw = "[see [1]](/x/@bob) end"

      expect(link_extractor.extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end

    # Text nested too deep for any link pattern still leaves its `](…)`
    # destination consumed, not walked into.
    it "leaves a mention alone in the destination of a link too nested to match" do
      raw = "[a [b [c]]](/x/@bob) end"

      expect(link_extractor.extract(raw)).to eq(raw)
      expect(buffer.mentions).to be_empty
    end
  end

  # An unpaired backtick is literal text in CommonMark, so it must not open a code
  # span that swallows the rest of the post. A span exists only when a matching
  # closer follows within the same paragraph. Every expectation here was checked
  # against PrettyText.
  describe "inline code spans" do
    let(:hashtag_names) do
      Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("general")])
    end
    let(:hashtag_extractor) do
      described_class.new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:)
    end
    let(:emoji_extractor) do
      described_class.new(
        embeds: buffer,
        markdown_engine:,
        mention_names:,
        hashtag_names:,
        custom_emoji_names: %w[parrot],
      )
    end

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
    # `extract` builds its constructs internally and never produces an unknown
    # node, so this guard is unreachable through the public API; open up the
    # private method deliberately to exercise it.
    seam =
      Class
        .new(described_class) { public :defer }
        .new(embeds: buffer, mention_names:, hashtag_names:, markdown_engine:)

    expect { seam.defer(Object.new, "@x") }.to raise_error(NotImplementedError, /Object/)
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

  describe "verbatim originals" do
    # Every deferred row carries the exact matched source slice, so the
    # importer can restore it unchanged when the embed cannot be mapped —
    # rebuilding a canonical form loses titles, spacing and casing.
    it "records the matched slice on every kind of row" do
      extract(<<~RAW, topic_id: 7)
        [quote="alice, post:2"]
        hi @bob, see #support
        [/quote]
        [text](/t/topic/5) and ![p](upload://abc.png)
      RAW

      expect(buffer.quotes.first[:original_markdown]).to eq(%q{[quote="alice, post:2"]})
      expect(buffer.mentions.first[:original_markdown]).to eq("@bob")
      expect(buffer.hashtags.first[:original_markdown]).to eq("#support")
      expect(buffer.links.first[:original_markdown]).to eq("[text](/t/topic/5)")
      expect(buffer.uploads.first[:original_markdown]).to eq("![p](upload://abc.png)")
    end
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
          described_class.new(
            embeds: buffer,
            markdown_engine:,
            mention_names:,
            hashtag_names:,
            internal_link_hosts: {
              "forum.example.com" => nil,
            },
          )
        host_extractor.extract("Höhe https://forum.example.com/t/thema/9 an")

        expect(buffer.links.first).to include(target_id: 9)
      end

      it "still defers a custom emoji" do
        emoji_extractor =
          described_class.new(
            embeds: buffer,
            markdown_engine:,
            mention_names:,
            hashtag_names:,
            custom_emoji_names: %w[parrot],
          )
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
