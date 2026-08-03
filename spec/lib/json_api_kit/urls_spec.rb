# frozen_string_literal: true

RSpec.describe JsonApiKit::Urls do
  subject(:urls) { described_class.new(base:, current:, parameters:) }

  let(:base) { "https://example.com/api" }
  let(:current) { "https://example.com/api/topics" }
  let(:parameters) { { "page" => { "size" => "2" }, "sort" => "created_at" } }

  describe "#current" do
    it "returns the URL a caller read with the parameters they sent" do
      expect(urls.current.to_s).to eq(
        "https://example.com/api/topics?page%5Bsize%5D=2&sort=created_at",
      )
    end
  end

  describe "#record" do
    it "returns the URL of one record" do
      expect(urls.record("topics", "5").to_s).to eq("https://example.com/api/topics/5")
    end

    it "carries only the cursor a caller adds" do
      expect(urls.record("topics", "5").at(after: "a-cursor").to_s).to eq(
        "https://example.com/api/topics/5?page%5Bafter%5D=a-cursor",
      )
    end
  end

  describe "#relationship" do
    it "returns the URL of the relationship itself" do
      expect(urls.relationship("topics", "5", "posts").to_s).to eq(
        "https://example.com/api/topics/5/relationships/posts",
      )
    end
  end

  describe "#related" do
    it "returns the URL of the records a relationship points at" do
      expect(urls.related("topics", "5", "posts").to_s).to eq(
        "https://example.com/api/topics/5/posts",
      )
    end
  end
end
