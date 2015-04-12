require "spec_helper"

describe Onebox::Engine::ClassicGoogleMapsOnebox do

  URLS = {
    short: "https://goo.gl/maps/rEG3D",
    long: "https://www.google.de/maps/place/Statue+of+Liberty+National+Monument/@40.689249,-74.0445,17z/data=!3m1!4b1!4m2!3m1!1s0x89c25090129c363d:0x40c6a5770d25022b",
    canonical: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=classic&dg=ntvb",
    embed: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864"
  }

  before(:all) do
    FakeWeb.register_uri(:head, URLS[:short], response: "HTTP/1.1 302 Found\nLocation: #{URLS[:long]}\n\n")
    FakeWeb.register_uri(:head, URLS[:long], response: "HTTP/1.1 301 Moved Permanently\nLocation: #{URLS[:canonical]}\n\n")
  end

  subject { described_class.new(link) }

  it_behaves_like "an engine" do
    let(:link) { URLS[:canonical] }
    let(:data) { Onebox::Helpers.symbolize_keys(subject.send(:data)) }
  end

  shared_examples "embeddable" do |kind|
    let(:link) { URLS[kind] }

    it "resolves url correctly" do
      subject.url.should == URLS[:embed]
    end

    it "produces an iframe" do
      subject.to_html.should include("iframe", "output=embed")
    end

    it "produces a placeholder image" do
      subject.placeholder_html.should include("img")
    end
  end

  context "canonical url" do
    it_should_behave_like "embeddable", :canonical
  end

  context "long url" do
    it_should_behave_like "embeddable", :long
  end

  context "short url" do
    it_should_behave_like "embeddable", :short
  end

  context "maps/d/ url" do
    let(:link) { "https://www.google.com/maps/d/edit?mid=zPYyZFrHi1MU.kX85W_Y2y2_E" }
    it "isn't accepted" do
      expect{ subject }.to raise_exception(ArgumentError)
    end
  end

end

describe Onebox::Engine::CustomGoogleMapsOnebox do
  subject { described_class.new(link) }
  let(:link) { "https://www.google.com/maps/d/edit?mid=zPYyZFrHi1MU.kX85W_Y2y2_E" }

  it "rewrites url correctly" do
    subject.url.should == "https://www.google.com/maps/d/embed?mid=zPYyZFrHi1MU.kX85W_Y2y2_E"
  end

  it "produces an iframe" do
    subject.to_html.should include("iframe")
  end

  it "produces a placeholder image" do
    subject.placeholder_html.should include("img")
  end
end
