# frozen_string_literal: true

RSpec.describe SitemapController do
  describe "before_action :check_sitemap_enabled" do
    it "returns a 404 if sitemap is disabled" do
      Sitemap.touch(Sitemap::RECENT_SITEMAP_NAME)
      SiteSetting.enable_sitemap = false

      get "/sitemap.xml"

      expect(response.status).to eq(404)
    end

    it "returns a 404 if the request does't have a format" do
      get "/news"

      expect(response.status).to eq(404)
    end
  end

  describe "#index" do
    it "lists no sitemaps if we haven't generated them yet" do
      get "/sitemap.xml"

      sitemaps = Nokogiri::XML::Document.parse(response.body).css("loc")

      expect(sitemaps).to be_empty
    end

    it "lists generated sitemaps" do
      Sitemap.create!(name: "recent", enabled: true, last_posted_at: 1.minute.ago)

      get "/sitemap.xml"
      sitemaps = Nokogiri::XML::Document.parse(response.body).css("loc")

      expect(sitemaps.length).to eq(1)
      expect(sitemaps.first.text).to include("recent")
    end

    it "doesn't list disabled sitemaps" do
      Sitemap.create!(name: "recent", enabled: false, last_posted_at: 1.minute.ago)

      get "/sitemap.xml"
      sitemaps = Nokogiri::XML::Document.parse(response.body).css("loc")

      expect(sitemaps).to be_empty
    end
  end

  describe "#page" do
    before { Discourse.cache.delete("sitemap/1/#{SiteSetting.sitemap_page_size}") }

    it "returns a 404 if the sitemap doesn't exist" do
      get "/sitemap_999.xml"

      expect(response.status).to eq(404)
    end

    it "includes the topics for that page" do
      topic = Fabricate(:topic)
      Sitemap.create!(name: "1", enabled: true, last_posted_at: 1.minute.ago)

      get "/sitemap_1.xml"
      url = Nokogiri::XML::Document.parse(response.body).css("url").last
      loc = url.at_css("loc").text
      last_mod = url.at_css("lastmod").text

      expect(response.status).to eq(200)
      expect(loc).to eq("#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}")
      expect(last_mod).to eq(topic.bumped_at.xmlschema)
    end
  end

  describe "#recent" do
    let(:sitemap) { Sitemap.touch(Sitemap::RECENT_SITEMAP_NAME) }

    before { Discourse.cache.delete("sitemap/recent/#{sitemap.last_posted_at.to_i}") }

    it "returns a sitemap with topics bumped in the last three days" do
      topic = Fabricate(:topic, bumped_at: 1.minute.ago)
      old_topic = Fabricate(:topic, bumped_at: 6.days.ago)

      get "/sitemap_recent.xml"
      urls = Nokogiri::XML::Document.parse(response.body).css("url")
      loc = urls.first.at_css("loc").text
      last_mod = urls.first.at_css("lastmod").text

      expect(response.status).to eq(200)
      expect(loc).to eq("#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}")
      expect(last_mod).to eq(topic.bumped_at.xmlschema)

      all_urls = urls.map { |u| u.at_css("loc").text }
      expect(all_urls).not_to include("#{Discourse.base_url}/t/#{old_topic.slug}/#{old_topic.id}")
    end

    it "does not include page numbers" do
      topic = Fabricate(:topic, bumped_at: 1.minute.ago)
      page_size = TopicView.chunk_size

      two_page_size = page_size + 1
      topic.update!(posts_count: two_page_size, updated_at: 2.hour.ago)
      get "/sitemap_recent.xml"
      url = Nokogiri::XML::Document.parse(response.body).at_css("loc").text
      expect(url).not_to include("?page=2")
    end
  end

  describe "#news" do
    let!(:sitemap) { Sitemap.touch(Sitemap::NEWS_SITEMAP_NAME) }

    before { Discourse.cache.delete("sitemap/news") }

    it "returns a sitemap with topics bumped in the last 72 hours" do
      topic = Fabricate(:topic, bumped_at: 71.hours.ago)
      old_topic = Fabricate(:topic, bumped_at: 73.hours.ago)

      get "/news.xml"
      urls = Nokogiri::XML::Document.parse(response.body).css("url")
      loc = urls.first.at_css("loc").text

      expect(response.status).to eq(200)
      expect(loc).to eq("#{Discourse.base_url}/t/#{topic.slug}/#{topic.id}")

      all_urls = urls.map { |u| u.at_css("loc").text }
      expect(all_urls).not_to include("#{Discourse.base_url}/t/#{old_topic.slug}/#{old_topic.id}")
    end
  end
end
