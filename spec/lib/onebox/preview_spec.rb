require "spec_helper"

describe Onebox::Preview do
  before(:all) { fake("http://www.amazon.com", response("amazon")) }
  before(:each) { Onebox.options.cache.clear }

  let(:preview) { described_class.new("http://www.amazon.com") }

  describe "#to_s" do
    let(:to_s) { preview.to_s }
    it "returns some html if given a valid url" do
      title = "Knit Noro: Accessories: 30 Colorful Little Knits [Hardcover]"
      expect(to_s).to include(title)
    end
    it "returns an empty string if the resource is not found"
    it "returns an empty string if the resource fails to load"

    it "returns an empty string if the url is not valid" do
      expect(described_class.new('not a url').to_s).to eq("")
    end
  end

  describe "#engine" do
    it "returns an engine" do
      expect(preview.send(:engine)).to be_an(Onebox::Engine)
    end
  end
end
