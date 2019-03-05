require 'spec_helper'

RSpec.describe Onebox::Helpers do
  describe '.blank?' do
    it { expect(described_class.blank?("")).to be(true) }
    it { expect(described_class.blank?(" ")).to be(true) }
    it { expect(described_class.blank?("test")).to be(false) }
    it { expect(described_class.blank?(["test", "testing"])).to be(false) }
    it { expect(described_class.blank?([])).to be(true) }
    it { expect(described_class.blank?({})).to be(true) }
    it { expect(described_class.blank?(nil)).to be(true) }
    it { expect(described_class.blank?(true)).to be(false) }
    it { expect(described_class.blank?(false)).to be(true) }
    it { expect(described_class.blank?(a: 'test')).to be(false) }
  end

  describe ".truncate" do
    let(:test_string) { "Chops off on spaces" }
    it { expect(described_class.truncate(test_string)).to eq(test_string) }
    it { expect(described_class.truncate(test_string, 5)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 7)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string, 9)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 10)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string, 100)).to eq("Chops off on spaces") }
    it { expect(described_class.truncate(" #{test_string} ", 6)).to eq(" Chops...") }
  end

  describe "fetch_response" do
    after(:each) do
      Onebox.options = Onebox::DEFAULTS
    end

    before do
      Onebox.options = { max_download_kb: 1 }
      fake("http://example.com/large-file", response("slides"))
    end

    it "raises an exception when responses are larger than our limit" do
      expect {
        described_class.fetch_response('http://example.com/large-file')
      }.to raise_error(Onebox::Helpers::DownloadTooLarge)
    end
  end

  describe "user_agent" do
    before do
      fake("http://example.com/some-resource", body: 'test')
    end

    context "default" do
      it "has the Ruby user agent" do
        described_class.fetch_response('http://example.com/some-resource')
        expect(FakeWeb.last_request.to_hash['user-agent'][0]).to eq("Ruby")
      end
    end

    context "Custom option" do
      after(:each) do
        Onebox.options = Onebox::DEFAULTS
      end

      before do
        Onebox.options = { user_agent: "EvilTroutBot v0.1" }
      end

      it "has the custom user agent" do
        described_class.fetch_response('http://example.com/some-resource')
        expect(FakeWeb.last_request.to_hash['user-agent'][0]).to eq("EvilTroutBot v0.1")
      end
    end
  end

end
