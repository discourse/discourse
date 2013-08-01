require "spec_helper"

describe Discourse::Oneboxer::Preview::Amazon do
  describe "#to_html" do
    it "returns template if given valid data" do
      amazon = described_class.new(Nokogiri::HTML(File.read(File.join("spec", "fixtures", "amazon.response"))))
      expect(amazon.to_html).to eq(onebox_view(%|\n<h1>Knit Noro: Accessories: 30 Colorful Little Knits [Hardcover]</h1>\n<h2 class="host">amazon.com</h2>\n<img src="foo.coms" />\n<p>Lorem Ipsum</p>\n<p>Price</p>\n|))
    end
  end
end
