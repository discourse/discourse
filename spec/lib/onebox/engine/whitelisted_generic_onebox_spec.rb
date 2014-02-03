require "spec_helper"

describe Onebox::Engine::WhitelistedGenericOnebox do

  describe ".===" do
    before do
      described_class.whitelist = %w(eviltrout.com discourse.org)
    end

    it "matches an entire domain" do
      expect(described_class === URI('http://eviltrout.com/resource')).to eq(true)
    end

    it "matches a subdomain" do
      expect(described_class === URI('http://www.eviltrout.com/resource')).to eq(true)
    end

    it "doesn't match a different domain" do
      expect(described_class === URI('http://goodtuna.com/resource')).to eq(false)
    end

    it "doesn't match the period as any character" do
      expect(described_class === URI('http://eviltrouticom/resource')).to eq(false)
    end

    it "doesn't match a prefixed domain" do
      expect(described_class === URI('http://aneviltrout.com/resource')).to eq(false)
    end
  end


  describe 'rewrites' do
    class DummyOnebox < Onebox::Engine::WhitelistedGenericOnebox
      def generic_html
        "<iframe src='https://youtube.com/asdf'></iframe>"
      end
    end

    it "doesn't rewrite URLs that arent in the list" do
      Onebox::Engine::WhitelistedGenericOnebox.rewrites = []
      DummyOnebox.new("http://youtube.com").to_html.should == "<iframe src='https://youtube.com/asdf'></iframe>"
    end

    it "rewrites URLs when whitelisted" do
      Onebox::Engine::WhitelistedGenericOnebox.rewrites = %w(youtube.com)
      DummyOnebox.new("http://youtube.com").to_html.should == "<iframe src='//youtube.com/asdf'></iframe>"
    end
  end


end
