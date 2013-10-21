require "spec_helper"

describe Onebox::Engine::AmazonOnebox do
  before(:all) do
    @link = "http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:onebox) { described_class.new(link) }
  let(:html) { onebox.to_html }
  let(:data) { onebox.send(:data) }
  let(:link) { @link }

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
