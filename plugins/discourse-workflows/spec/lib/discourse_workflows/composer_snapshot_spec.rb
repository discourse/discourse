# frozen_string_literal: true

RSpec.describe DiscourseWorkflows::ComposerSnapshot do
  describe ".own_text" do
    it "removes quotes, quoted lines and HTML comments" do
      raw = <<~MD
        [quote="sam, post:1, topic:2"]Magic words[/quote]
        [quote]a [quote]b[/quote] food stand[/quote]
        > bad food
        <!-- Magic words -->
        Hello world
      MD

      expect(described_class.own_text(raw).squish).to eq("Hello world")
    end

    it "keeps unclosed quotes and comments as text" do
      expect(described_class.own_text("[quote]Magic words")).to eq("[quote]Magic words")
      expect(described_class.own_text("<!-- Magic words")).to eq("<!-- Magic words")
      expect(described_class.own_text("Magic words[/quote]")).to eq("Magic words[/quote]")
    end

    it "keeps text around an unclosed quote while removing the closed ones inside it" do
      expect(described_class.own_text("[quote]a [quote]b[/quote] Magic words")).to eq(
        "[quote]a  Magic words",
      )
    end

    it "handles deeply nested quotes in linear time" do
      depth = 2_000
      raw = "#{"[quote]" * depth}Magic words#{"[/quote]" * depth} Hello"

      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      text = described_class.own_text(raw)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

      expect(text).to eq(" Hello")
      expect(elapsed).to be < 0.5
    end
  end

  describe "#own_text" do
    fab!(:user)

    it "only looks at what a post can hold" do
      SiteSetting.max_post_length = 20
      snapshot =
        described_class.new(
          user:,
          action: "create_topic",
          draft_key: "new_topic",
          raw: "#{"a" * 20} Magic words",
        )

      expect(snapshot.raw.length).to eq(20)
      expect(snapshot.own_text).not_to include("Magic words")
    end
  end
end
