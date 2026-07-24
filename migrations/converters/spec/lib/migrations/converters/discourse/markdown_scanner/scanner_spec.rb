# frozen_string_literal: true

RSpec.describe Migrations::Converters::Discourse::MarkdownScanner::Scanner do
  let(:detectors) { [Migrations::Converters::Discourse::MarkdownScanner::Detectors::Mention.new] }

  def scan(input, &block)
    described_class.new(detectors:, &block).scan(input)
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

  def deferred_names(input)
    names = []
    scan(input) { |node| names << node.name }
    names
  end

  # A span closes only on a backtick run of the opener's exact length that is a
  # full backtick string, so a length-2 run inside a `` `…` `` span is content,
  # not a closer. All expectations here were checked against PrettyText.
  describe "inline code with a mismatched backtick run" do
    it "closes at the final backtick, so a mention after the span is deferred" do
      # `a``b` is one span closing at the last single backtick; @bob is outside it.
      expect(deferred_names("`a``b` see @bob")).to eq(%w[bob])
    end

    it "keeps a mention inside the span undeferred" do
      # `a``@bob` is one span; @bob is code, not a mention.
      expect(deferred_names("`a``@bob`")).to eq([])
    end

    it "reopens a single-backtick span after a double run that never closes" do
      # ``x`y` — the `` opens no span (no `` closer), so it stays literal; the
      # single-backtick span `y` follows, leaving @bob outside it.
      expect(deferred_names("``x`y` @bob")).to eq(%w[bob])
    end
  end

  # An unpaired backtick is literal text (CommonMark), so it must not suppress
  # detection for the rest of the post the way an open inline-code state used to.
  describe "an unpaired backtick" do
    it "stays literal and keeps detecting the mention after it" do
      expect(deferred_names("a`@bob here")).to eq(%w[bob])
    end

    it "does not pair across a blank line, leaving both mentions detectable" do
      expect(deferred_names("`@alice\n\n@bob`")).to eq(%w[alice bob])
    end
  end
end
