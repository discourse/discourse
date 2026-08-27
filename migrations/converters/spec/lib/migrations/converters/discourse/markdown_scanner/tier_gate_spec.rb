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
      scanner::Detectors::Mention.new(names: mention_names),
      scanner::Detectors::Hashtag.new(names: hashtag_names),
      scanner::Detectors::Emoji.new(names: %w[parrot]),
    ]
  end

  it "classifies a body without any candidate character as :none" do
    expect(gate.classify("plain prose, nothing here.")).to eq(:none)
  end

  it "classifies a body whose candidates name nothing as :none" do
    expect(gate.classify("hello @stranger, PR #123 and :smile:")).to eq(:none)
  end

  describe "real candidates" do
    it "routes only metadata-bearing quote openers to :engine" do
      # A plain [quote] block holds no user/post/topic fields — nothing any
      # extraction path defers (proven in the engine-scanner spec) — while an
      # opener with metadata does, whatever core's tag casing.
      expect(gate.classify("[quote]\njust quoted text\n[/quote]")).to eq(:none)
      expect(gate.classify("[quote=alice]\nx\n[/quote]")).to eq(:engine)
      expect(gate.classify("[QUOTE=\"alice, post:1\"]\nx\n[/QUOTE]")).to eq(:engine)
    end

    it "routes a known mention to :engine" do
      expect(gate.classify("hello @alice")).to eq(:engine)
    end

    it "routes a known hashtag to :engine" do
      expect(gate.classify("filed under #support")).to eq(:engine)
    end

    it "treats a quote opener as a candidate without probing names" do
      expect(gate.classify(%{[quote="whoever"]\nhi\n[/quote]})).to eq(:engine)
    end

    it "treats an upload reference as a candidate" do
      expect(gate.classify("![p](upload://abc.png)")).to eq(:engine)
    end

    it "treats supported full upload URLs as candidates, but not generic uploads paths" do
      sha1 = "0123456789abcdef0123456789abcdef01234567"
      expect(gate.classify("/uploads/default/original/2X/#{sha1}.png")).to eq(:engine)
      expect(gate.classify("/uploads/short-url/aZ9.png")).to eq(:engine)
      # A WordPress-style path has neither supported shape. Without the
      # detector check, every such body would pay an engine parse.
      expect(gate.classify("https://blog.example.net/wp-content/uploads/2009/12/a.jpg")).to eq(
        :none,
      )
    end

    it "treats an internal route as a candidate" do
      expect(gate.classify("see /t/some-topic/123")).to eq(:engine)
    end

    it "treats a configured host as a candidate" do
      expect(gate.classify("https://forum.example.com/faq")).to eq(:engine)
    end

    it "counts a custom emoji as a candidate but not a standard one" do
      expect(gate.classify(":parrot:")).to eq(:engine)
      expect(gate.classify(":smile:")).to eq(:none)
    end

    it "probes candidates the same next to context-sensitive syntax" do
      expect(gate.classify("`code` and @alice")).to eq(:engine)
      expect(gate.classify("`code` and @stranger and #nothing and :smile:")).to eq(:none)
    end
  end

  describe "character entities" do
    it "routes a numeric entity that decodes to a construct character to :engine" do
      # `&#64;` is `@`: the byte checks cannot see the mention it spells.
      expect(gate.classify("&#64;bob")).to eq(:engine)
      expect(gate.classify("&#x40;bob")).to eq(:engine)
    end

    it "ignores a numeric entity that decodes to typography" do
      # `&#8217;` is a right single quotation mark; its literal `#` matches
      # the presence check, so only the decode keeps this body out.
      expect(gate.classify("it&#8217;s fine")).to eq(:none)
    end

    it "ignores the allowlisted named entities" do
      expect(gate.classify("Tom &amp; Jerry")).to eq(:none)
      expect(gate.classify("wait &hellip; more")).to eq(:none)
    end

    it "routes an unlisted named entity to :engine" do
      # `&commat;` is `@`; unknown names are assumed construct-capable.
      expect(gate.classify("&commat;bob")).to eq(:engine)
      expect(gate.classify("&frac12; of it")).to eq(:engine)
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
      expect(gate.classify("%pct")).to eq(:engine)
      expect(gate.classify("plain")).to eq(:none)
    end
  end
end
