require 'rails_helper'
require 'quote_comparer'

describe QuoteComparer do

  describe "#modified?" do
    let(:post) { Fabricate(:post, raw: "This has **text** we _are_ matching") }

    def qc(text)
      QuoteComparer.new(post.topic_id, post.post_number, text)
    end

    it "returns true for no post" do
      expect(QuoteComparer.new(nil, nil, "test")).to be_modified
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
