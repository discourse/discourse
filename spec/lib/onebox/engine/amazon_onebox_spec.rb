require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  before(:all) do
    @link = "http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

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
