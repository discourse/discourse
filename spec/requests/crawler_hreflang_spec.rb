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
  end
end
