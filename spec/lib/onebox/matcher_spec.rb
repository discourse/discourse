require "spec_helper"

describe Onebox::Matcher do
  describe "#oneboxed" do
    it "returns Example onebox when given example url" do
      matcher = described_class.new("http://example.com")
      expect(matcher.oneboxed).to be(Onebox::Engine::ExampleOnebox)
    end

    it "returns Amazon onebox when given amazon url" do
      matcher = described_class.new("http://amazon.com")
      expect(matcher.oneboxed).to be(Onebox::Engine::AmazonOnebox)
    end

    it "returns Flickr onebox when given flickr url" do
      matcher = described_class.new("http://flickr.com")
      expect(matcher.oneboxed).to be(Onebox::Engine::FlickrOnebox)
    end
  end
end
