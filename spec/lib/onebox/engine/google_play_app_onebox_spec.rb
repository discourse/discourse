require "spec_helper"

describe Onebox::Engine::GooglePlayAppOnebox do
  before(:all) do
    @link = "https://play.google.com/store/apps/details?id=com.hulu.plus&hl=en"
    fake(@link, response(described_class.template_name))
  end
  before(:each) { Onebox.defaults.cache.clear }

  let(:link) { @link }

  it_behaves_like "an engine"

  describe "#to_html" do
    let(:html) { described_class.new(link).to_html }

    it "returns the product title" do
      expect(html).to include("Hulu Plus")
    end

    it "returns the product image" do
      expect(html).to include("https://lh5.ggpht.com/v8ODfPPNzQYv5xnNkZJEUg71RSLpNQgNulm8ChFcX5c3QgZd2293-JH08z41G8hlCw=w300-rw")
    end

    it "returns the product description" do
      expect(html).to include("Instantly watch current TV shows and acclaimed movies. Anywhere.")
    end

    it "returns the product URL" do
      expect(html).to include(link)
    end
  end
end
