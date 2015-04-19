require "spec_helper"

describe Onebox::Engine::GoogleMapsOnebox do

  URLS = {
    short: {
      test: "https://goo.gl/maps/rEG3D",
      embed: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
      streetview: false
    },
    long: {
      test: "https://www.google.de/maps/place/Statue+of+Liberty+National+Monument/@40.689249,-74.0445,17z/data=!3m1!4b1!4m2!3m1!1s0x89c25090129c363d:0x40c6a5770d25022b",
      embed: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
      streetview: false
    },
    canonical: {
      test: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=classic&dg=ntvb",
      embed: "https://maps.google.de/maps?sll=40.689249,-74.0445&sspn=0.0062479,0.0109864&cid=4667599994556318251&q=Statue+of+Liberty+National+Monument&output=embed&dg=ntvb&ll=40.689249,-74.0445&spn=0.0062479,0.0109864",
      streetview: false
    },
    custom: {
      test: "https://www.google.com/maps/d/edit?mid=zPYyZFrHi1MU.kX85W_Y2y2_E",
      embed: "https://www.google.com/maps/d/embed?mid=zPYyZFrHi1MU.kX85W_Y2y2_E",
      streetview: false
    },
    streetview: {
      test: "https://www.google.com/maps/@46.414384,10.013947,3a,75y,232.83h,99.08t/data=!3m5!1e1!3m3!1s9WgYUb5quXDjqqFd3DWI6A!2e0!3e5?hl=de",
      embed: "https://www.google.com/maps/embed?pb=!3m2!2sen!4v0!6m8!1m7!1s9WgYUb5quXDjqqFd3DWI6A!2m2!1d46.414384!2d10.013947!3f232.83!4f9.908!5f0.75",
      streetview: true
    }
  }

  before(:all) do
    FakeWeb.register_uri(:head, URLS[:short][:test], response: "HTTP/1.1 302 Found\nLocation: #{URLS[:long][:test]}\n\n")
    FakeWeb.register_uri(:head, URLS[:long][:test], response: "HTTP/1.1 301 Moved Permanently\nLocation: #{URLS[:canonical][:test]}\n\n")
  end

  subject { described_class.new(link) }

  URLS.each do |kind, urls|

    context "given a #{kind.to_s} url" do
      let(:link) { urls[:test] }
      let(:data) { Onebox::Helpers.symbolize_keys(subject.send(:data)) }

      it_behaves_like "an engine"

      it "detects streetview urls" do
        expect(subject.streetview?).to urls[:streetview] ? be_truthy : be_falsey
      end

      it "resolves url correctly" do
        expect(subject.url).to eq urls[:embed]
      end

      it "produces an iframe" do
        expect(subject.to_html).to include("<iframe")
      end

      it "produces a placeholder image" do
        expect(subject.placeholder_html).to include("<img")
      end
    end

  end
end
