# frozen_string_literal: true

require "quote_comparer"

RSpec.describe QuoteComparer do
  describe "#missing?" do
    fab!(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    it "returns true for missing topic and post" do
      expect(QuoteComparer.new(nil, nil, "test")).to be_missing
    end

    it "returns true for missing topic" do
      expect(QuoteComparer.new(nil, post.post_number, "test")).to be_missing
    end

    it "returns true for missing post" do
      expect(QuoteComparer.new(post.topic_id, nil, "test")).to be_missing
    end

    it "returns false for only missing text" do
      expect(QuoteComparer.new(post.topic_id, post.post_number, nil)).to_not be_missing
    end

    it "returns false for no missing topic and post" do
      expect(QuoteComparer.new(post.topic_id, post.post_number, "test")).to_not be_missing
    end
  end

  describe "#modified?" do
    fab!(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    def qc(text)
      QuoteComparer.new(post.topic_id, post.post_number, text)
    end

    it "returns true for nil text" do
      expect(qc(nil)).to be_modified
    end

    it "returns true for empty text" do
      expect(qc("")).to be_modified
    end

    it "returns true for modified text" do
      expect(qc("text is modified")).to be_modified
    end

    it "return false when the text matches exactly" do
      expect(qc("This has text we are matching")).not_to be_modified
    end

    it "return false when there's a substring" do
      expect(qc("text we are")).not_to be_modified
    end

    it "return false when there's extra space" do
      expect(qc("\n\ntext   we are \t")).not_to be_modified
    end
  end
end
