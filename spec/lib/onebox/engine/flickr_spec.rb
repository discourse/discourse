require "spec_helper"

describe Onebox::Engine::Flickr do
  describe "#to_html" do
    let(:link) { "http://flickr.com" }
    let(:html) { described_class.new(link).to_html }

    before do
      fake(link, response("flickr.response"))
    end

    it "returns photo title" do
      expect(html).to include("Los Angeles View 2011")
    end

    it "returns product URL" do
      expect(html).to include(link)
    end

  end
end
