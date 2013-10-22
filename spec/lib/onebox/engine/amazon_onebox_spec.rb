require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  before(:all) do
    @link = "http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
  end

  include_context "engines"
  it_behaves_like "an engine"

  describe "#to_html" do
    it "includes image" do
      expect(html).to include("61mI3YmHVnL._BO2,204,203,200_PIsitb-sticker-arrow-click,TopRight,35,-76_AA300_SH20_OU01_.jpg")
    end

    it "includes description" do
      expect(html).to include("Using only the finest natural materials and ecologically sound")
    end

    it "returns the product price" do
      expect(html).to include("$18.77")
    end
  end
end
