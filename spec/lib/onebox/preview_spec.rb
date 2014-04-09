require "spec_helper"

describe Onebox::Preview do

  before do
    fake("http://www.amazon.com/product", response("amazon"))
    FakeWeb.register_uri(:get, "http://www.amazon.com/404-url", status: 404)
    FakeWeb.register_uri(:get, "http://www.amazon.com/500-url", status: 500)
    FakeWeb.register_uri(:get, "http://www.amazon.com/error-url", status: 500)
    FakeWeb.register_uri(:get, "http://www.amazon.com/timeout-url", exception: Timeout::Error)
    FakeWeb.register_uri(:get, "http://www.amazon.com/http-error", exception: Net::HTTPError)
    FakeWeb.register_uri(:get, "http://www.amazon.com/error-connecting", exception: Errno::ECONNREFUSED)
  end

  let(:preview) { described_class.new("http://www.amazon.com/product") }

  describe "#to_s" do
    it "returns some html if given a valid url" do
      title = "Knit Noro: Accessories"
      expect(preview.to_s).to include(title)
    end

    it "returns an empty string if the resource is missing" do
      expect(described_class.new("http://www.amazon.com/404-url").to_s).to eq("")
    end

    it "returns an empty string if the resource returns an error" do
      expect(described_class.new("http://www.amazon.com/500-url").to_s).to eq("")
    end

    it "returns an empty string if the resource times out" do
      expect(described_class.new("http://www.amazon.com/timeout-url").to_s).to eq("")
    end

    it "returns an empty string if there is an http error" do
      expect(described_class.new("http://www.amazon.com/http-error").to_s).to eq("")
    end

    it "returns an empty string if there is an error connecting" do
      expect(described_class.new("http://www.amazon.com/error-connecting").to_s).to eq("")
    end

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
