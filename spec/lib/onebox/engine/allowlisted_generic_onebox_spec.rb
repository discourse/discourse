# frozen_string_literal: true

require "rails_helper"

describe Onebox::Engine::AllowlistedGenericOnebox do
  describe ".===" do
    it "matches any domain" do
      expect(described_class === URI('http://foo.bar/resource')).to be(true)
    end

    it "doesn't match an IP address" do
      expect(described_class === URI('http://1.2.3.4/resource')).to be(false)
      expect(described_class === URI('http://1.2.3.4:1234/resource')).to be(false)
    end
  end

  describe 'html_providers' do
    class HTMLOnebox < Onebox::Engine::AllowlistedGenericOnebox
      def data
        {
          html: 'cool html',
          height: 123,
          provider_name: 'CoolSite',
        }
      end
    end

    it "doesn't return the HTML when not in the `html_providers`" do
      Onebox::Engine::AllowlistedGenericOnebox.html_providers = []
      expect(HTMLOnebox.new("http://coolsite.com").to_html).to be_nil
    end

    it "returns the HMTL when in the `html_providers`" do
      Onebox::Engine::AllowlistedGenericOnebox.html_providers = ['CoolSite']
      expect(HTMLOnebox.new("http://coolsite.com").to_html).to eq "cool html"
    end
  end

  describe 'rewrites' do
    class DummyOnebox < Onebox::Engine::AllowlistedGenericOnebox
      def generic_html
        "<iframe src='http://youtube.com/asdf'></iframe>"
      end
    end

    it "doesn't rewrite URLs that arent in the list" do
      Onebox::Engine::AllowlistedGenericOnebox.rewrites = []
      expect(DummyOnebox.new("http://youtube.com").to_html).to eq "<iframe src='http://youtube.com/asdf'></iframe>"
    end

    it "rewrites URLs when allowlisted" do
      Onebox::Engine::AllowlistedGenericOnebox.rewrites = %w(youtube.com)
      expect(DummyOnebox.new("http://youtube.com").to_html).to eq "<iframe src='https://youtube.com/asdf'></iframe>"
    end
  end

  describe 'oembed_providers' do
    let(:url) { "http://www.meetup.com/Toronto-Ember-JS-Meetup/events/219939537" }

    before do
      stub_request(:get, url).to_return(status: 200, body: onebox_response('meetup'))
      stub_request(:get, "http://api.meetup.com/oembed?url=#{url}").to_return(status: 200, body: onebox_response('meetup_oembed'))
    end

    it 'uses the endpoint for the url' do
      onebox = described_class.new("http://www.meetup.com/Toronto-Ember-JS-Meetup/events/219939537")
      expect(onebox.raw).not_to be_nil
      expect(onebox.raw[:title]).to eq "February EmberTO Meet-up"
    end
  end

  describe "cookie support" do
    let(:url) { "http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html" }

    it "sends the cookie with the request" do
      stub_request(:get, url)
        .with(headers: { cookie: 'evil=trout' })
        .to_return(status: 200, body: onebox_response('dailymail'))

      onebox = described_class.new(url)
      onebox.options = { cookie: "evil=trout" }

      expect(onebox.to_html).not_to be_empty
    end

    it "fetches site_name and article_published_time tags" do
      stub_request(:get, url).to_return(status: 200, body: onebox_response('dailymail'))
      onebox = described_class.new(url)

      expect(onebox.to_html).to include("Mail Online &ndash; 8 Aug 14")
    end
  end

  describe 'canonical link' do
    context 'uses canonical link if available' do
      let(:mobile_url) { "https://m.etsy.com/in-en/listing/87673424/personalized-word-pillow-case-letter" }
      let(:canonical_url) { "https://www.etsy.com/in-en/listing/87673424/personalized-word-pillow-case-letter" }
      before do
        stub_request(:get, mobile_url).to_return(status: 200, body: onebox_response('etsy_mobile'))
        stub_request(:get, canonical_url).to_return(status: 200, body: onebox_response('etsy'))
        stub_request(:head, canonical_url).to_return(status: 200, body: "")
      end

      it 'fetches opengraph data and price from canonical link' do
        onebox = described_class.new(mobile_url)
        expect(onebox.to_html).not_to be_nil
        expect(onebox.to_html).to include("images/favicon.ico")
        expect(onebox.to_html).to include("Etsy")
        expect(onebox.to_html).to include("Personalized Word Pillow Case")
        expect(onebox.to_html).to include("Allow your personality to shine through your decor; this contemporary and modern accent will help you do just that.")
        expect(onebox.to_html).to include("https://i.etsystatic.com/6088772/r/il/719b4b/1631899982/il_570xN.1631899982_2iay.jpg")
        expect(onebox.to_html).to include("CAD 52.00")
      end
    end

    context 'does not use canonical link for Discourse topics' do
      let(:discourse_topic_url) { "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483" }
      let(:discourse_topic_reply_url) { "https://meta.discourse.org/t/congratulations-most-stars-in-2013-github-octoverse/12483/2" }
      before do
        stub_request(:get, discourse_topic_url).to_return(status: 200, body: onebox_response('discourse_topic'))
        stub_request(:get, discourse_topic_reply_url).to_return(status: 200, body: onebox_response('discourse_topic_reply'))
      end

      it 'fetches opengraph data from original link' do
        onebox = described_class.new(discourse_topic_reply_url)
        expect(onebox.to_html).not_to be_nil
        expect(onebox.to_html).to include("Congratulations, most stars in 2013 GitHub Octoverse!")
        expect(onebox.to_html).to include("Thanks for that link and thank you – and everyone else who is contributing to the project!")
        expect(onebox.to_html).to include("https://d11a6trkgmumsb.cloudfront.net/optimized/2X/d/d063b3b0807377d98695ee08042a9ba0a8c593bd_2_690x362.png")
      end
    end
  end

  describe 'to_html' do
    let(:original_link) { "http://www.dailymail.co.uk/pages/live/articles/news/news.html?in_article_id=479146&in_page_id=1770" }
    let(:redirect_link) { 'http://www.dailymail.co.uk/news/article-479146/Brutality-justice-The-truth-tarred-feathered-drug-dealer.html' }

    before do
      stub_request(:get, original_link).to_return(
        status: 301,
        headers: {
          location: redirect_link,
        }
      )
      stub_request(:get, redirect_link).to_return(status: 200, body: onebox_response('dailymail'))
      stub_request(:head, redirect_link).to_return(status: 200, body: "")
    end

    around do |example|
      previous_options = Onebox.options.to_h
      example.run
      Onebox.options = previous_options
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

  describe 'missing description' do
    context 'works without description if image is present' do
      before do
        stub_request(:get, "https://edition.cnn.com/2020/05/15/health/gallery/coronavirus-people-adopting-pets-photos/index.html")
          .to_return(status: 200, body: onebox_response('cnn'))
        stub_request(:get, "https://www.cnn.com/2020/05/15/health/gallery/coronavirus-people-adopting-pets-photos/index.html")
          .to_return(status: 200, body: onebox_response('cnn'))
        stub_request(:head, "https://www.cnn.com/2020/05/15/health/gallery/coronavirus-people-adopting-pets-photos/index.html")
          .to_return(status: 200, body: "")
      end

      it 'shows basic onebox' do
        onebox = described_class.new("https://edition.cnn.com/2020/05/15/health/gallery/coronavirus-people-adopting-pets-photos/index.html")
        expect(onebox.to_html).not_to be_nil
        expect(onebox.to_html).to include("https://edition.cnn.com/2020/05/15/health/gallery/coronavirus-people-adopting-pets-photos/index.html")
        expect(onebox.to_html).to include("https://cdn.cnn.com/cnnnext/dam/assets/200427093451-10-coronavirus-people-adopting-pets-super-tease.jpg")
        expect(onebox.to_html).to include("People are fostering and adopting pets during the pandemic")
      end
    end

    context 'uses basic meta description when necessary' do
      before do
        stub_request(:get, "https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition/")
          .to_return(status: 200, body: onebox_response('reddit_image'))
        stub_request(:get, "https://www.example.com/content")
          .to_return(status: 200, body: onebox_response('basic_description'))
      end

      it 'uses opengraph tags when present' do
        onebox = described_class.new("https://www.reddit.com/r/colors/comments/b4d5xm/literally_nothing_black_edition/")
        expect(onebox.to_html).to include("4 votes and 1 comment so far on Reddit")
      end

      it 'fallback to basic meta description if other description tags are missing' do
        onebox = described_class.new("https://www.example.com/content")
        expect(onebox.to_html).to include("basic meta description")
      end
    end
  end

  describe 'article html hosts' do
    context 'returns article_html for hosts in article_html_hosts' do
      before do
        stub_request(:get, "https://www.imdb.com/title/tt0108002/")
          .to_return(status: 200, body: onebox_response('imdb'))
      end

      it 'shows article onebox' do
        onebox = described_class.new("https://www.imdb.com/title/tt0108002/")
        expect(onebox.to_html).to include("https://www.imdb.com/title/tt0108002")
        expect(onebox.to_html).to include("https://m.media-amazon.com/images/M/MV5BZGUzMDU1YmQtMzBkOS00MTNmLTg5ZDQtZjY5Njk4Njk2MmRlXkEyXkFqcGdeQXVyNjc1NTYyMjg@._V1_FMjpg_UX1000_.jpg")
        expect(onebox.to_html).to include("Rudy (1993) - IMDb")
        expect(onebox.to_html).to include("Rudy: Directed by David Anspaugh. With Sean Astin, Jon Favreau, Ned Beatty, Greta Lind. Rudy has always been told that he was too small to play college football.")
      end
    end
  end
end
