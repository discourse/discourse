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

  describe 'html_providers' do
    class HTMLOnebox < Onebox::Engine::WhitelistedGenericOnebox
      def data
        {
          html: 'cool html',
          height: 123,
          provider_name: 'CoolSite',
        }
      end
    end

    it "doesn't return the HTML when not in the `html_providers`" do
      Onebox::Engine::WhitelistedGenericOnebox.html_providers = []
      expect(HTMLOnebox.new("http://coolsite.com").to_html).to be_nil
    end

    it "returns the HMTL when in the `html_providers`" do
      Onebox::Engine::WhitelistedGenericOnebox.html_providers = ['CoolSite']
      expect(HTMLOnebox.new("http://coolsite.com").to_html).to eq "cool html"
    end
  end

  describe 'rewrites' do
    class DummyOnebox < Onebox::Engine::WhitelistedGenericOnebox
      def generic_html
        "<iframe src='http://youtube.com/asdf'></iframe>"
      end
    end

    it "doesn't rewrite URLs that arent in the list" do
      Onebox::Engine::WhitelistedGenericOnebox.rewrites = []
      expect(DummyOnebox.new("http://youtube.com").to_html).to eq "<iframe src='http://youtube.com/asdf'></iframe>"
    end

    it "rewrites URLs when whitelisted" do
      Onebox::Engine::WhitelistedGenericOnebox.rewrites = %w(youtube.com)
      expect(DummyOnebox.new("http://youtube.com").to_html).to eq "<iframe src='https://youtube.com/asdf'></iframe>"
    end
  end

  describe 'oembed_providers' do
    let(:url) { "http://www.meetup.com/Toronto-Ember-JS-Meetup/events/219939537" }

    before do
      fake(url, response('meetup'))
      fake("http://api.meetup.com/oembed?url=#{url}", response('meetup_oembed'))
    end

    it 'uses the endpoint for the url' do
      onebox = described_class.new("http://www.meetup.com/Toronto-Ember-JS-Meetup/events/219939537")
      expect(onebox.raw).not_to be_nil
      expect(onebox.raw[:title]).to eq "February EmberTO Meet-up"
    end
  end

  describe 'to_html' do
    before do
      described_class.whitelist = %w(dailymail.co.uk discourse.org)
      original_link = "http://www.dailymail.co.uk/pages/live/articles/news/news.html?in_article_id=479146&in_page_id=1770"
      redirect_link = 'http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html'
      FakeWeb.register_uri(
        :get,
        original_link,
        status: ["301", "Moved Permanently"],
        location: redirect_link
      )
      fake(redirect_link, response('dailymail'))
      onebox = described_class.new(original_link)
      @html = onebox.to_html
    end
    let(:html) { @html }

    it "follows redirects and includes the summary" do
      expect(html).to include("It was the most chilling image of the week")
    end
  end

end
