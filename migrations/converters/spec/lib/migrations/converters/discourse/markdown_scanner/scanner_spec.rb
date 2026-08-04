# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Scanner do
  let(:mention_names) do
    Migrations::SortedStringSet.new(
      %w[alice bob café].map { |name| Migrations::NameNormalizer.normalize(name) },
    )
  end

  let(:detectors) do
    [
      Migrations::Converters::Discourse::MarkdownScanner::Detectors::Mention.new(
        names: mention_names,
      ),
    ]
  end

  def scan(input, &block)
    described_class.new(detectors:, &block).scan(input)
  end

  # The name of every mention the scanner handed to the block, in order — so a
  # spec can say which mentions were seen without caring what they rendered as.
  def detected_names(input)
    names = []
    scan(input) { |node| names << node.name }
    names
  end

  it "replaces a matched span with the block's return value" do
    result = scan("hey @alice there") { |node| "<#{node.name}>" }

    expect(result).to eq("hey <alice> there")
  end

  it "keeps the matched text verbatim when the block declines with nil" do
    nodes = []
    result =
      scan("hey @alice there") do |node|
        nodes << node
        nil
      end

    expect(nodes.map(&:name)).to eq(%w[alice])
    expect(result).to eq("hey @alice there")
  end

  it "keeps multibyte text around a declined match intact" do
    result = scan("héllo @café_team hi") { nil }

    expect(result).to eq("héllo @café_team hi")
    expect(result).to be_valid_encoding
  end

  # A span closes only on a backtick run of the opener's exact length that is a
  # full backtick string, so a length-2 run inside a `` `…` `` span is content,
  # not a closer. All expectations here were checked against PrettyText.
  describe "inline code with a mismatched backtick run" do
    it "closes at the final backtick, so a mention after the span is detected" do
      # `a``b` is one span closing at the last single backtick; @bob is outside it.
      expect(detected_names("`a``b` see @bob")).to eq(%w[bob])
    end

    it "leaves a mention inside the span undetected" do
      # `a``@bob` is one span; @bob is code, not a mention.
      expect(detected_names("`a``@bob`")).to eq([])
    end

    it "reopens a single-backtick span after a double run that never closes" do
      # ``x`y` — the `` opens no span (no `` closer), so it stays literal; the
      # single-backtick span `y` follows, leaving @bob outside it.
      expect(detected_names("``x`y` @bob")).to eq(%w[bob])
    end
  end

  # An unpaired backtick is literal text (CommonMark), so it must not suppress
  # detection for the rest of the post the way an open inline-code state used to.
  describe "an unpaired backtick" do
    it "stays literal and keeps detecting the mention after it" do
      expect(detected_names("a`@bob here")).to eq(%w[bob])
    end

    it "does not pair across a blank line, leaving both mentions detectable" do
      expect(detected_names("`@alice\n\n@bob`")).to eq(%w[alice bob])
    end
  end

  # Block structure is decided before inline spans, so a line that starts a new
  # block ends the paragraph and the backtick before it never pairs. Checked
  # against PrettyText.
  describe "a backtick run a new block interrupts" do
    ["# h", "===", "- b", "1. b", "> b", "***", "[quote=\"b\"]"].each do |line|
      it "leaves the run literal across a #{line.inspect} line" do
        expect(detected_names("`x\n#{line}\n@bob`")).to eq(%w[bob])
      end
    end

    # The run stays literal here too, but the block those two open is code, so
    # what follows is suppressed by the block phase rather than by the span.
    %w[``` <pre>].each do |line|
      it "leaves the run literal across a #{line.inspect} line, which opens code" do
        expect(detected_names("`x\n#{line}\n@bob`")).to eq([])
        expect(detected_names("`x\n#{line}")).to eq([])
      end
    end

    it "pairs across an ordinary line, which continues the paragraph" do
      expect(detected_names("`x\nplain\n@bob`")).to eq([])
    end

    # An indented line cannot interrupt a paragraph, so it is a lazy continuation
    # rather than code.
    it "pairs across an indented line" do
      expect(detected_names("`x\n    y\n@bob`")).to eq([])
    end
  end

  # `[` is always a stop character, so an inline `[code]` span suppresses
  # detection even for a detector set that has no `[`-triggered detector of its
  # own.
  describe "an inline [code] span" do
    it "suppresses a mention inside it" do
      expect(detected_names("see [code]@bob[/code] ok")).to eq([])
    end

    it "keeps detecting after it" do
      expect(detected_names("see [code]x[/code] @bob")).to eq(%w[bob])
    end

    it "leaves an unclosed [code] literal" do
      expect(detected_names("see [code]@bob ok")).to eq(%w[bob])
    end

    it "passes an unclaimed bracket through unchanged" do
      expect(scan("see [x] @bob") { |node| "<#{node.name}>" }).to eq("see [x] <bob>")
    end
  end
end
