require "spec_helper"

describe Discourse::Oneboxer::Preview do
  describe "#to_s" do
    it "returns some html if given a valid url" do
      # fake("http://example.com", "<b></b>")
      preview = described_class.new("http://example.com")
      expect(preview.to_s).to eq(onebox_view("<h1>Example Domain</h1>"))

      # fake("http://www.example.com", "<i></i>")
      preview = described_class.new("http://www.example.com")
      expect(preview.to_s).to eq(onebox_view("<h1>Example Domain</h1>"))

      # preview = described_class.new("http://www.amazon.com/Knit-Noro-Accessories-Colorful-Little/dp/193609620X/ref=wl_it_dp_o_pC_nS_nC?ie=UTF8&colid=20OK33RM0J6W4&coliid=I12BNT2SU5KGJ7")
      # expect(preview.to_s).to eq(onebox_view(%|\n<h1>Knit Noro: Accessories: 30 Colorful Little Knits [Hardcover]</h1>\n<h2 class="host">amazon.com</h2>\n<img src="foo.coms" />\n<p>Lorem Ipsum</p>\n<p>Price</p>\n|))
    end
  end
end
