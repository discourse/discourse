# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::TierGate do
  subject(:gate) { described_class.new(detectors:) }

  let(:scanner) { Migrations::Converters::Discourse::MarkdownScanner }

  let(:mention_names) do
    Migrations::CompactStringSet.new(
      %w[alice bob].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end
  let(:hashtag_names) do
    Migrations::CompactStringSet.new([Migrations::NameNormalizer.normalize("support")])
  end

  let(:detectors) do
    [
      scanner::Detectors::Upload.new,
      scanner::Detectors::UploadUrl.new,
      scanner::Detectors::Quote.new,
      scanner::Detectors::InternalLink.new(
        hosts: {
          "forum.example.com" => nil,
        },
        base_prefix: nil,
        on_foreign_host: nil,
      ),
      scanner::Detectors::LinkSpan.new,
      scanner::Detectors::Mention.new(names: mention_names),
      scanner::Detectors::Hashtag.new(names: hashtag_names),
      scanner::Detectors::Emoji.new(names: %w[parrot]),
    ]
  end

  it "classifies a body without any candidate character as :none" do
    expect(gate.classify("plain prose, nothing here.")).to eq(:none)
  end

  it "classifies candidates without context-sensitive syntax as :prose" do
    expect(gate.classify("hello @alice and #support")).to eq(:prose)
  end

  it "keeps a danger-free body :prose even when its candidates name nothing" do
    # Cheap either way: the prose walk runs the same detectors and extracts
    # nothing, so no probe is spent on the classification.
    expect(gate.classify("hello @stranger")).to eq(:prose)
  end

  describe "context-sensitive syntax" do
    {
      "inline code" => "`code` and @alice",
      "a backslash" => "\\* @alice",
      "an HTML tag" => "<b>hi</b> @alice",
      "a CR line ending" => "line\r@alice",
      "a tilde fence" => "~~~\ntext\n~~~\n@alice",
      "an indented line" => "    indented\n@alice",
      "a [code] block" => "[code]x[/code] @alice",
      "a [code=lang] block" => "[code=ruby]\nx\n[/code]\n@alice",
      "a [code lang=x] block" => "[code lang=ruby]\nx\n[/code]\n@alice",
      "an indented line inside a blockquote" => "> Intro\n>\n>     x\n@alice",
      "a space-then-tab indent" => "Intro\n\n \tx\n@alice",
      "link syntax" => "[here](/t/5) @alice",
      "a reference-style link" => "[here][1] @alice",
      "a single-line quote" => %{[quote="alice, post:2, topic:5"]inline[/quote]},
    }.each do |label, raw|
      it "routes a real candidate next to #{label} to :engine" do
        expect(gate.classify(raw)).to eq(:engine)
      end
    end

    it "does not read a quote opener with only trailing spaces as single-line" do
      expect(gate.classify(%{[quote="alice, post:2, topic:5"]  \nbody\n[/quote]})).to eq(:prose)
    end

    it "classifies dangers with no real candidate as :none" do
      expect(gate.classify("`code` and @stranger and #nothing and :smile:")).to eq(:none)
    end

    it "treats a quote opener as a real candidate without probing names" do
      expect(gate.classify(%{`x` [quote="whoever"]hi[/quote]})).to eq(:engine)
    end

    it "treats an upload reference as a real candidate" do
      expect(gate.classify("`x` ![p](upload://abc.png)")).to eq(:engine)
    end

    it "treats an internal route as a real candidate" do
      expect(gate.classify("`x` see /t/some-topic/123")).to eq(:engine)
    end

    it "treats a configured host as a real candidate" do
      expect(gate.classify("`x` https://forum.example.com/faq")).to eq(:engine)
    end

    it "counts a custom emoji as a real candidate but not a standard one" do
      expect(gate.classify("`x` :parrot:")).to eq(:engine)
      expect(gate.classify("`x` :smile:")).to eq(:none)
    end
  end

  describe "character entities" do
    it "routes a numeric entity that decodes to a construct character to :engine" do
      # `&#64;` is `@`: the regex tiers cannot see the mention it spells.
      expect(gate.classify("&#64;bob")).to eq(:engine)
      expect(gate.classify("&#x40;bob")).to eq(:engine)
    end

    it "ignores a numeric entity that decodes to typography" do
      # `&#8217;` is a right single quotation mark.
      expect(gate.classify("it&#8217;s #support")).to eq(:prose)
    end

    it "ignores the allowlisted named entities" do
      expect(gate.classify("Tom &amp; Jerry #support")).to eq(:prose)
      expect(gate.classify("wait &hellip; #support")).to eq(:prose)
    end

    it "routes an unlisted named entity to :engine" do
      # `&commat;` is `@`; unknown names are assumed construct-capable.
      expect(gate.classify("&commat;bob")).to eq(:engine)
      expect(gate.classify("&frac12; of #support")).to eq(:engine)
    end

    it "leaves a body whose only presence signal is an irrelevant entity in :prose" do
      # `&#8217;` carries a literal `#`, so the presence check can't rule the
      # body out — but the prose walk then extracts nothing, which costs one
      # cheap pass rather than an engine trip.
      expect(gate.classify("it&#8217;s fine")).to eq(:prose)
    end
  end

  describe "the named-entity allowlist" do
    # The gate's allowlist claims these names can never spell a construct.
    # markdown-it's own name table ships only as an encoded trie, so the claim
    # is verified against the real decoder: every allowlisted name must decode
    # to characters no construct can contain (or not decode at all — a
    # non-entity can't spell anything either).
    it "only lists names markdown-it decodes to non-construct characters" do
      require "mini_racer"

      context = MiniRacer::Context.new
      begin
        dist =
          File.join(
            Migrations::Converters::MarkdownEngine.discourse_root,
            "frontend/discourse-markdown-it/node_modules/markdown-it/dist/markdown-it.js",
          )
        context.eval(File.read(dist), filename: "markdown-it.js")
        context.eval(
          "const __md = markdownit(); function __decode(s) { const tokens = __md.parseInline(s, {}); return tokens[0].children.map(t => t.content).join(''); }",
        )

        construct_char = described_class.const_get(:CONSTRUCT_CHAR)
        allowlist = described_class::IRRELEVANT_NAMED_ENTITIES

        offenders =
          allowlist.filter do |name|
            decoded = context.call("__decode", "&#{name};")
            decoded != "&#{name};" && decoded.each_char.any? { |c| construct_char.match?(c) }
          end

        expect(offenders).to be_empty

        # Positive control: the mechanism must see a construct-capable name.
        expect(context.call("__decode", "&commat;")).to eq("@")
      ensure
        context.dispose
      end
    end
  end

  describe "an unfamiliar detector" do
    let(:detectors) do
      stub =
        Class.new(Migrations::Converters::Discourse::MarkdownScanner::Detectors::Base) do
          const_set(:TRIGGERS, ["%"].freeze)

          def detect(_input, _pos, _byte)
            nil
          end

          def presence_pattern
            /%pct/
          end
        end
      [stub.new]
    end

    it "assumes candidacy whenever presence hits, so classification stays conservative" do
      expect(gate.classify("`x` %pct")).to eq(:engine)
      expect(gate.classify("plain")).to eq(:none)
    end
  end
end
