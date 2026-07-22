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

  # A backtick run closes an inline span only when its length matches the opener
  # exactly (CommonMark). A length-2 run inside a `…` span must be skipped whole,
  # not close the span at its second backtick.
  describe "inline code with a mismatched backtick run" do
    def deferred_names(input)
      names = []
      scan(input) { |node| names << node.name }
      names
    end

    it "closes at the final backtick, so a mention after the span is deferred" do
      # `a``b` is one span closing at the last single backtick; @bob is outside it.
      expect(deferred_names("`a``b` see @bob")).to eq(%w[bob])
    end

    it "keeps a mention inside the span undeferred" do
      # `a``@bob` is one span; @bob is code, not a mention.
      expect(deferred_names("`a``@bob`")).to eq([])
    end
  end
end
