# frozen_string_literal: true

require "rails_helper"

RSpec.describe MarkdownEndpoint::AcceptHeader do
  describe ".preferred?" do
    it "uses specificity, quality, and the historical HTML tie-break" do
      expect(described_class.preferred?("text/markdown")).to eq(true)
      expect(described_class.preferred?("text/markdown, text/html")).to eq(false)
      expect(described_class.preferred?("text/markdown;q=0, text/html;q=0.1")).to eq(false)
      expect(described_class.preferred?("text/markdown;q=0.8, application/json;q=0.9")).to eq(false)
      expect(described_class.preferred?("text/markdown;q=0.8, text/*;q=0.9")).to eq(false)
      expect(described_class.preferred?("text/markdown;q=0.8, text/html;q=0.7")).to eq(true)
      expect(described_class.preferred?("*/*")).to eq(false)
      expect(described_class.preferred?(nil)).to eq(false)
    end
  end
end
