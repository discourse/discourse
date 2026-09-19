# frozen_string_literal: true

RSpec.describe DiscourseAi::Completions::TextNormalization do
  subject(:normalizer) { Class.new { include DiscourseAi::Completions::TextNormalization }.new }

  before { enable_current_plugin }

  describe "#force_utf8" do
    it "scrubs invalid bytes" do
      expect(normalizer.force_utf8("caf\xFFe".dup.force_encoding("UTF-8"))).to eq("cafe")
    end

    it "strips a byte order mark" do
      expect(normalizer.force_utf8("\xEF\xBB\xBFhello".dup.force_encoding("UTF-8"))).to eq("hello")
    end

    it "tolerates nil" do
      expect(normalizer.force_utf8(nil)).to eq("")
    end
  end

  describe "#normalize_document_text" do
    it "collapses whitespace and trims" do
      expect(normalizer.normalize_document_text("  a b\r\nc \n\n\n\nd  ")).to eq("a b\nc\n\nd")
    end

    it "caps the output one character past the budget, so the encoder can detect truncation" do
      text = normalizer.normalize_document_text("a" * (described_class::DOCUMENT_TEXT_BUDGET + 50))

      expect(text.length).to eq(described_class::DOCUMENT_TEXT_BUDGET + 1)
    end
  end

  describe "#normalize_inline_text" do
    it "flattens all whitespace to single spaces" do
      expect(normalizer.normalize_inline_text(" a b\n\tc ")).to eq("a b c")
    end
  end
end
