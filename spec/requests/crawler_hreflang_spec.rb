# frozen_string_literal: true

describe "Crawler hreflang tags" do
  fab!(:user)
  fab!(:post) { Fabricate(:post, user:) }

  describe "when viewing a topic as crawler" do
    before do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = true
      SiteSetting.content_localization_supported_locales = "en|ja|es"
    end

    it "includes hreflang tags when viewed as crawler" do
      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include('<link rel="alternate" href=')
      expect(response.body).to include('hreflang="x-default"')
      expect(response.body).to include('hreflang="en"')
      expect(response.body).to include('hreflang="ja"')
      expect(response.body).to include('hreflang="es"')
      expect(response.body).to include("?#{Discourse::LOCALE_PARAM}=ja")
    end

    it "doesn't include hreflang tags for normal users" do
      get "/t/#{post.topic.slug}/#{post.topic.id}"

      expect(response.body).not_to include('hreflang="x-default"')
    end

    it "doesn't include hreflang tags when settings are disabled" do
      SiteSetting.content_localization_enabled = false
      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).not_to include('hreflang="x-default"')
    end

    it "self-canonicalizes translated topic pages when ?tl= is present" do
      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="canonical" href="#{Discourse.base_url}/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja">),
      )
      expect(response.headers["X-Robots-Tag"].to_s).not_to include("noindex")
    end

    it "self-canonicalizes translated list pages when ?tl= is present" do
      get "/latest?#{Discourse::LOCALE_PARAM}=ja",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="canonical" href="#{Discourse.base_url}/latest?#{Discourse::LOCALE_PARAM}=ja">),
      )
    end

    it "does not append ?tl= to canonical when locale param is absent" do
      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/t/#{post.topic.slug}/#{post.topic.id}"\s*/?>},
      )
    end

    it "ignores ?tl= when the locale is not in the supported list" do
      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=xyz",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="canonical" href="#{Discourse.base_url}/t/#{post.topic.slug}/#{post.topic.id}">),
      )
    end

    it "uses & as separator when another allowed param is present" do
      Fabricate.times(35, :post, topic: post.topic, user:)

      get "/t/#{post.topic.slug}/#{post.topic.id}?page=2&#{Discourse::LOCALE_PARAM}=ja",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="canonical" href="#{Discourse.base_url}/t/#{post.topic.slug}/#{post.topic.id}?page=2&amp;#{Discourse::LOCALE_PARAM}=ja">),
      )
    end

    it "does not modify canonical when content_localization_crawler_param is disabled" do
      SiteSetting.content_localization_crawler_param = false

      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/t/#{post.topic.slug}/#{post.topic.id}"\s*/?>},
      )
    end

    it "does not append ?tl= to canonical for non-crawler requests" do
      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja"

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/t/#{post.topic.slug}/#{post.topic.id}"\s*/?>},
      )
    end
  end
end
