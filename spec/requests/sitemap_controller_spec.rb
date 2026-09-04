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
    def sitemap_index_entries
      get "/sitemap.xml"

      Nokogiri::XML::Document
        .parse(response.body)
        .css("sitemap")
        .to_h { |sitemap| [sitemap.at_css("loc").text, sitemap.at_css("lastmod").text] }
    end

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

    it "removes a stale published pages sitemap entry after eligibility is lost" do
      SiteSetting.enable_page_publishing = true
      Fabricate(:published_page, public: true, slug: "indexed-post")
      Sitemap.regenerate_sitemaps

      expect(sitemap_index_entries.keys).to include(
        "#{Discourse.base_url}/sitemap_#{Sitemap::PUBLISHED_PAGES_SITEMAP_NAME}.xml",
      )

      SiteSetting.enable_page_publishing = false

      expect(sitemap_index_entries.keys).not_to include(
        "#{Discourse.base_url}/sitemap_#{Sitemap::PUBLISHED_PAGES_SITEMAP_NAME}.xml",
      )
      expect(Sitemap.find_by(name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME).enabled).to eq(false)
    end

    it "updates the published pages sitemap lastmod when source topic visibility changes" do
      SiteSetting.enable_page_publishing = true
      newer_page = Fabricate(:published_page, public: true, slug: "newer-post")
      older_topic = Fabricate(:topic, updated_at: 2.hours.ago)
      older_page = Fabricate(:published_page, public: true, slug: "older-post", topic: older_topic)
      newer_page.update!(updated_at: 1.hour.ago)
      older_page.update!(updated_at: 2.hours.ago)
      Sitemap.regenerate_sitemaps

      loc = "#{Discourse.base_url}/sitemap_#{Sitemap::PUBLISHED_PAGES_SITEMAP_NAME}.xml"
      previous_lastmod = Time.zone.parse(sitemap_index_entries.fetch(loc))
      older_topic.update!(visible: false, updated_at: 1.minute.from_now)

      expect(Time.zone.parse(sitemap_index_entries.fetch(loc))).to be > previous_lastmod
    end

    it "does not update the published pages sitemap lastmod for private page changes" do
      SiteSetting.enable_page_publishing = true
      public_page = Fabricate(:published_page, public: true, slug: "public-post")
      private_page = Fabricate(:published_page, public: false, slug: "private-post")
      public_page.update!(updated_at: 2.hours.ago)
      private_page.update!(updated_at: 1.hour.from_now)
      Sitemap.regenerate_sitemaps

      loc = "#{Discourse.base_url}/sitemap_#{Sitemap::PUBLISHED_PAGES_SITEMAP_NAME}.xml"

      expected_lastmod = [
        public_page.reload.updated_at,
        public_page.topic.updated_at,
        public_page.topic.category.updated_at,
      ].max

      lastmod = Time.zone.parse(sitemap_index_entries.fetch(loc))

      expect(lastmod.to_i).to eq(expected_lastmod.to_i)
      expect(lastmod).to be < private_page.updated_at
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

    it "generates correct page numbers based on the topic post count" do
      topic = Fabricate(:topic, bumped_at: 1.minute.ago)
      page_size = TopicView.chunk_size

      incomplete_page_size = TopicView.chunk_size - 1
      topic.update!(posts_count: incomplete_page_size, updated_at: 4.hours.ago)
      get "/sitemap_recent.xml"
      url = Nokogiri::XML::Document.parse(response.body).at_css("loc").text
      expect(url).not_to include("?page=2")

      topic.update!(posts_count: page_size, updated_at: 3.hours.ago)
      get "/sitemap_recent.xml"
      url = Nokogiri::XML::Document.parse(response.body).at_css("loc").text
      expect(url).not_to include("?page=2")

      two_page_size = page_size + 1
      topic.update!(posts_count: two_page_size, updated_at: 2.hours.ago)
      get "/sitemap_recent.xml"
      url = Nokogiri::XML::Document.parse(response.body).at_css("loc").text
      expect(url).to include("?page=2")
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

  describe "#published_pages" do
    before { SiteSetting.enable_page_publishing = true }

    def published_page_locs
      get "/sitemap_published_pages.xml"

      Nokogiri::XML::Document.parse(response.body).css("loc").map(&:text)
    end

    it "returns 404 when no eligible published pages exist" do
      get "/sitemap_published_pages.xml"
      expect(response.status).to eq(404)
    end

    it "lists public published pages whose source topic is in a public category" do
      page = Fabricate(:published_page, public: true, slug: "public-post")

      locs = published_page_locs

      expect(response.status).to eq(200)
      expect(locs).to contain_exactly("#{Discourse.base_url}/pub/#{page.slug}")
    end

    it "returns 404 when login_required is enabled" do
      Fabricate(:published_page, public: true, slug: "public-post")
      SiteSetting.login_required = true
      SiteSetting.show_published_pages_login_required = true
      sign_in(Fabricate(:user))

      get "/sitemap_published_pages.xml"

      expect(response.status).to eq(404)
    end

    it "excludes non-public pages" do
      public_page = Fabricate(:published_page, public: true, slug: "public-post")
      Fabricate(:published_page, public: false, slug: "private-post")

      locs = published_page_locs

      expect(locs).to contain_exactly("#{Discourse.base_url}/pub/#{public_page.slug}")
    end

    it "excludes pages whose source topic is in a read-restricted category" do
      public_page = Fabricate(:published_page, public: true, slug: "public-post")
      restricted = Fabricate(:private_category, group: Fabricate(:group))
      topic = Fabricate(:topic, category: restricted)
      Fabricate(:published_page, public: true, slug: "restricted-post", topic: topic)

      locs = published_page_locs

      expect(locs).to contain_exactly("#{Discourse.base_url}/pub/#{public_page.slug}")
    end

    it "excludes pages whose source topic is not visible" do
      public_page = Fabricate(:published_page, public: true, slug: "public-post")
      hidden_topic = Fabricate(:topic, visible: false)
      Fabricate(:published_page, public: true, slug: "hidden-post", topic: hidden_topic)

      locs = published_page_locs

      expect(locs).to contain_exactly("#{Discourse.base_url}/pub/#{public_page.slug}")
    end

    it "does not serve stale URLs after sitemap membership shrinks" do
      newer_page = Fabricate(:published_page, public: true, slug: "newer-post")
      older_topic = Fabricate(:topic)
      older_page = Fabricate(:published_page, public: true, slug: "older-post", topic: older_topic)
      older_page.update!(updated_at: 1.day.ago)
      newer_page.update!(updated_at: 1.minute.ago)

      expect(published_page_locs).to contain_exactly(
        "#{Discourse.base_url}/pub/#{newer_page.slug}",
        "#{Discourse.base_url}/pub/#{older_page.slug}",
      )

      older_topic.update!(visible: false)

      expect(published_page_locs).to contain_exactly("#{Discourse.base_url}/pub/#{newer_page.slug}")
    end

    it "returns 404 when there are more published pages than a sitemap supports" do
      SiteSetting.sitemap_page_size = 1
      Fabricate(:published_page, public: true, slug: "first-post")
      Fabricate(:published_page, public: true, slug: "second-post")

      get "/sitemap_published_pages.xml"

      expect(response.status).to eq(404)
    end

    it "returns 404 when published pages are not available to anonymous visitors" do
      Fabricate(:published_page, public: true, slug: "public-post")

      SiteSetting.enable_page_publishing = false
      get "/sitemap_published_pages.xml"
      expect(response.status).to eq(404)

      # secure_uploads has a validator that requires s3 uploads + acls
      # to be on first, so we use setup_s3 to satisfy it. The thing
      # we actually want to test is publishable_pages returning none
      # when secure_uploads is on, hiding the sitemap.
      setup_s3
      SiteSetting.enable_page_publishing = true
      SiteSetting.secure_uploads = true
      get "/sitemap_published_pages.xml"
      expect(response.status).to eq(404)
    end
  end

  describe ".regenerate_sitemaps and the published_pages entry" do
    before { SiteSetting.enable_page_publishing = true }

    it "adds an enabled published_pages sitemap row when eligible pages exist" do
      Fabricate(:published_page, public: true, slug: "indexed-post")

      Sitemap.regenerate_sitemaps

      row = Sitemap.find_by(name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME)
      expect(row).to be_present
      expect(row.enabled).to eq(true)
    end

    it "disables the published_pages row when no eligible pages remain" do
      Sitemap.create!(
        name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME,
        enabled: true,
        last_posted_at: 1.minute.ago,
      )

      Sitemap.regenerate_sitemaps

      row = Sitemap.find_by(name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME)
      expect(row).to be_present
      expect(row.enabled).to eq(false)
    end

    it "disables the published_pages row when there are more published pages than a sitemap supports" do
      SiteSetting.sitemap_page_size = 1
      Fabricate(:published_page, public: true, slug: "first-post")
      Fabricate(:published_page, public: true, slug: "second-post")
      row =
        Sitemap.create!(
          name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME,
          enabled: true,
          last_posted_at: 1.minute.ago,
        )

      Sitemap.regenerate_sitemaps

      expect(row.reload.enabled).to eq(false)
    end

    it "disables the published_pages row when published pages are not available to anonymous visitors" do
      Fabricate(:published_page, public: true, slug: "indexed-post")
      row =
        Sitemap.create!(
          name: Sitemap::PUBLISHED_PAGES_SITEMAP_NAME,
          enabled: true,
          last_posted_at: 1.minute.ago,
        )

      SiteSetting.enable_page_publishing = false
      Sitemap.regenerate_sitemaps
      expect(row.reload.enabled).to eq(false)

      # secure_uploads has a validator that requires s3 uploads + acls
      # to be on first; setup_s3 satisfies the validator so the actual
      # branch under test (publishable_pages returning none with
      # secure_uploads on) is what runs.
      setup_s3
      SiteSetting.enable_page_publishing = true
      SiteSetting.secure_uploads = true
      row.update!(enabled: true)
      Sitemap.regenerate_sitemaps
      expect(row.reload.enabled).to eq(false)

      SiteSetting.secure_uploads = false
      SiteSetting.login_required = true
      SiteSetting.show_published_pages_login_required = true
      row.update!(enabled: true)
      Sitemap.regenerate_sitemaps
      expect(row.reload.enabled).to eq(false)
    end
  end
end
