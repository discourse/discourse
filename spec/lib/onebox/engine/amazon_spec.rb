require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  describe "#to_html" do
    let(:link) { "http://amazon.com" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("amazon.response"))
    end

    it "returns the product title" do
      expect(html).to include("Knit Noro: Accessories: 30 Colorful Little Knits [Hardcover]")
    end

    it "returns the product image" do
      expect(html).to include("61mI3YmHVnL._BO2,204,203,200_PIsitb-sticker-arrow-click,TopRight,35,-76_AA300_SH20_OU01_.jpg")
    end

    it "returns the product description" do
      expect(html).to include("Using only the finest natural materials and ecologically sound")
    end

    it "returns the product price" do
      expect(html).to include("$18.77")
    end

    it "returns the product URL" do
      expect(html).to include(link)
    end

  end
end
