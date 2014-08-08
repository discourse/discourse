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

  describe 'to_html' do

    before do
      described_class.whitelist = %w(dailymail.co.uk discourse.org)
      original_link = "http://www.dailymail.co.uk/pages/live/articles/news/news.html?in_article_id=479146&in_page_id=1770"
      redirect_link = 'http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html'
      FakeWeb.register_uri(:get, original_link, status: ["301", "Moved Permanently"], location: '/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html')
      fake(redirect_link, response('dailymail'))
      onebox = described_class.new(original_link)
      @html = onebox.to_html
    end
    let(:html) { @html }

    it "includes summary" do
      expect(html).to include("It was the most chilling image of the week")
    end
  end

end
