# frozen_string_literal: true

RSpec.describe DiscourseAi::Utils::TextSummary do
  describe ".truncate" do
    it "returns the original text when it is shorter than max" do
      expect(described_class.truncate("hello", max: 10)).to eq("hello")
    end

    it "truncates text longer than max" do
      expect(described_class.truncate("hello world", max: 5)).to eq("hello …")
    end

    it "returns nil for nil input" do
      expect(described_class.truncate(nil, max: 10)).to be_nil
    end
  end

  describe ".word_count" do
    it "counts whitespace-separated words" do
      expect(described_class.word_count("hello world")).to eq(2)
    end

    it "returns 0 for nil and empty input" do
      expect(described_class.word_count(nil)).to eq(0)
      expect(described_class.word_count("")).to eq(0)
    end
  end
end
