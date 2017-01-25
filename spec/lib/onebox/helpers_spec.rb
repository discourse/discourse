require 'spec_helper'

RSpec.describe Onebox::Helpers do
  describe '.blank?' do
    it { expect(described_class.blank?("")).to be(true) }
    it { expect(described_class.blank?(" ")).to be(true) }
    it { expect(described_class.blank?("test")).to be(false) }
    it { expect(described_class.blank?(["test", "testing"])).to be(false) }
    it { expect(described_class.blank?([])).to be(true) }
    it { expect(described_class.blank?({})).to be(true) }
    it { expect(described_class.blank?({a: 'test'})).to be(false) }
    it { expect(described_class.blank?(nil)).to be(true) }
    it { expect(described_class.blank?(true)).to be(false) }
    it { expect(described_class.blank?(false)).to be(true) }
  end

  describe ".truncate" do
    let(:test_string) { "Chops off on spaces" }
    it { expect(described_class.truncate(test_string)).to eq(test_string) }
    it { expect(described_class.truncate(test_string,5)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string,7)).to eq("Chops...") }
    it { expect(described_class.truncate(test_string,9)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string,10)).to eq("Chops off...") }
    it { expect(described_class.truncate(test_string,100)).to eq("Chops off on spaces") }
    it { expect(described_class.truncate(" #{test_string} ",6)).to eq(" Chops...") }
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

end
