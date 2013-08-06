require "spec_helper"

describe Discourse::Oneboxer::Preview::Amazon do
  describe "#to_html" do
    it "returns the product title" do
      amazon = described_class.new(Nokogiri::HTML(File.read(File.join("spec","fixtures","amazon.response"))))
      expect(amazon.to_html).to include("Knit Noro: Accessories: 30 Colorful Little Knits [Hardcover]")
	  end

    it "returns the product image" do 
      amazon = described_class.new(Nokogiri::HTML(File.read(File.join("spec","fixtures","amazon.response"))))
      expect(amazon.to_html).to eq("http://ecx.images-amazon.com/images/I/61mI3YmHVnL._BO2,204,203,200_PIsitb-sticker-arrow-click,TopRight,35,-76_AA300_SH20_OU01_.jpg");
    end
  end
end
