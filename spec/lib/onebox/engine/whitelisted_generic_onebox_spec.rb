# frozen_string_literal: true

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

  describe "cookie support" do
    let(:url) { "http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html" }
    before do
      fake(url, response('dailymail'))
    end

    it "sends the cookie with the request" do
      onebox = described_class.new(url)
      onebox.options = { cookie: "evil=trout" }
      expect(onebox.to_html).not_to be_empty
      expect(FakeWeb.last_request['Cookie']).to eq('evil=trout')
    end

    it "fetches site_name and article_published_time tags" do
      onebox = described_class.new(url)
      expect(onebox.to_html).not_to be_empty

      expect(onebox.to_html).to include("Mail Online &ndash; 8 Aug 14")
    end
  end

  describe 'canonical link' do
    context 'uses canonical link if available' do
      let(:mobile_url) { "https://m.etsy.com/in-en/listing/87673424/personalized-word-pillow-case-letter" }
      let(:canonical_url) { "https://www.etsy.com/in-en/listing/87673424/personalized-word-pillow-case-letter" }
      before do
        fake(mobile_url, response('etsy_mobile'))
        fake(canonical_url, response('etsy'))
      end

      it 'fetches opengraph data and twitter labels from canonical link' do
        onebox = described_class.new(mobile_url)
        expect(onebox.to_html).not_to be_nil
        expect(onebox.to_html).to include("images/favicon.ico")
        expect(onebox.to_html).to include("Etsy")
        expect(onebox.to_html).to include("Personalized Word Pillow Case")
        expect(onebox.to_html).to include("Allow your personality to shine through your decor; this contemporary and modern accent will help you do just that.")
        expect(onebox.to_html).to include("https://img1.etsystatic.com/028/1/6088772/il_570xN.613262127_e0zl.jpg")
        expect(onebox.to_html).to include("CAD: $46.00")
        expect(onebox.to_html).not_to include("Available: 4")
      end
    end

    context 'does not use canonical link for Discourse topics' do
      let(:discourse_topic_url) { "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483" }
      let(:discourse_topic_reply_url) { "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483/2" }
      before do
        fake(discourse_topic_url, response('discourse_topic'))
        fake(discourse_topic_reply_url, response('discourse_topic_reply'))
      end

      it 'fetches opengraph data from original link' do
        onebox = described_class.new(discourse_topic_reply_url)
        expect(onebox.to_html).not_to be_nil
        expect(onebox.to_html).to include("Congratulations, most stars in 2013 GitHub Octoverse!")
        expect(onebox.to_html).to include("Thanks for that link and thank you -- and everyone else who is contributing to the project!")
        expect(onebox.to_html).to include("https://cdn-enterprise.discourse.org/meta/user_avatar/meta.discourse.org/codinghorror/200/5297_1.png")
      end
    end
  end

  describe 'to_html' do
    after(:each) do
      Onebox.options = Onebox::DEFAULTS
    end

    let(:original_link) { "http://www.dailymail.co.uk/pages/live/articles/news/news.html?in_article_id=479146&in_page_id=1770" }
    let(:redirect_link) { 'http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html' }

    before do
      described_class.whitelist = %w(dailymail.co.uk discourse.org)
      FakeWeb.register_uri(
        :get,
        original_link,
        status: ["301", "Moved Permanently"],
        location: redirect_link
      )
      fake(redirect_link, response('dailymail'))
    end

    it "follows redirects and includes the summary" do
      Onebox.options = { redirect_limit: 2 }
      onebox = described_class.new(original_link)
      expect(onebox.to_html).to include("It was the most chilling image of the week")
    end

    it "recives an error with too many redirects" do
      Onebox.options = { redirect_limit: 1 }
      onebox = described_class.new(original_link)
      expect(onebox.to_html).to be_nil
    end
  end

end
