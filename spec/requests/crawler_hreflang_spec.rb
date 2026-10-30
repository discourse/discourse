# frozen_string_literal: true

describe "Crawler hreflang tags" do
  fab!(:user)
  fab!(:post) { Fabricate(:post, user:) }

  describe "when viewing a topic as crawler" do
    before do
      SiteSetting.allow_user_locale = true
      SiteSetting.set_locale_from_param = true
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

    it "points the default locale's hreflang to the plain URL" do
      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="alternate" href="#{post.topic.url}" hreflang="en" />),
      )
      expect(response.body).not_to include("?#{Discourse::LOCALE_PARAM}=en")
    end

    it "includes the default locale's hreflang when the default locale isn't a supported locale" do
      SiteSetting.content_localization_supported_locales = "ja|es"

      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="alternate" href="#{post.topic.url}" hreflang="en" />),
      )
    end

    it "canonicalizes topic and list pages to the plain URL when ?tl= is the default locale" do
      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=en",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(post.topic.url)}"\s*/?>},
      )

      get "/latest?#{Discourse::LOCALE_PARAM}=en",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/latest"\s*/?>},
      )
    end

    context "when the plain URL may not serve the default locale" do
      let(:topic_path) { "/t/#{post.topic.slug}/#{post.topic.id}" }

      def expect_default_locale_param_urls
        expect(response.body).to include(
          %(<link rel="alternate" href="#{post.topic.url}?#{Discourse::LOCALE_PARAM}=en" hreflang="en" />),
        )
        expect(response.body).not_to include(
          %(<link rel="alternate" href="#{post.topic.url}" hreflang="en" />),
        )

        get "#{topic_path}?#{Discourse::LOCALE_PARAM}=en", headers: request_headers

        expect(response.body).to include(
          %(<link rel="canonical" href="#{post.topic.url}?#{Discourse::LOCALE_PARAM}=en">),
        )
      end

      context "with a crawler whose Accept-Language picks another locale" do
        let(:request_headers) do
          {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            "Accept-Language" => "ja",
          }
        end

        before { SiteSetting.set_locale_from_accept_language_header = true }

        it "keeps the default locale's locale param URL" do
          get topic_path, headers: request_headers

          expect(response.body).to include('<html lang="ja"')
          expect_default_locale_param_urls
        end
      end

      context "with a crawler whose language switcher cookie picks another locale" do
        let(:request_headers) do
          {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            "Cookie" => "locale=ja",
          }
        end

        before { SiteSetting.content_localization_language_switcher = "all" }

        it "keeps the default locale's locale param URL" do
          get topic_path, headers: request_headers

          expect(response.body).to include('<html lang="ja"')
          expect_default_locale_param_urls
        end
      end

      context "when set_locale_from_cookie is enabled" do
        let(:request_headers) do
          { "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }
        end

        before { SiteSetting.set_locale_from_cookie = true }

        it "keeps the default locale's locale param URL" do
          get topic_path, headers: request_headers

          expect_default_locale_param_urls
        end

        it "doesn't add the default locale when it isn't a supported locale" do
          SiteSetting.content_localization_supported_locales = "ja|es"

          get topic_path, headers: request_headers

          expect(response.body).to include('hreflang="ja"')
          expect(response.body).not_to include('hreflang="en"')
        end
      end

      context "with a signed-in user" do
        let(:request_headers) do
          { "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }
        end

        before { sign_in(user) }

        it "keeps the default locale's locale param URL" do
          get topic_path, headers: request_headers

          expect_default_locale_param_urls
        end
      end
    end

    it "uses hyphens instead of underscores in hreflang attribute for region-qualified locales" do
      SiteSetting.content_localization_supported_locales = "en|pt_BR|zh_CN"

      get "/t/#{post.topic.slug}/#{post.topic.id}",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include('hreflang="pt-BR"')
      expect(response.body).to include('hreflang="zh-CN"')
      expect(response.body).not_to include('hreflang="pt_BR"')
      expect(response.body).not_to include('hreflang="zh_CN"')

      expect(response.body).to include("?#{Discourse::LOCALE_PARAM}=pt_BR")
      expect(response.body).to include("?#{Discourse::LOCALE_PARAM}=zh_CN")
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

    it "does not emit translated crawler URLs when locale params are disabled" do
      SiteSetting.set_locale_from_param = false

      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja",
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      aggregate_failures do
        expect(response.body).not_to include('<link rel="alternate" href=')
        expect(response.body).to match(
          %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/t/#{post.topic.slug}/#{post.topic.id}"\s*/?>},
        )
      end
    end

    context "when viewing a later page of a topic" do
      fab!(:replies) { Fabricate.times(25, :post, topic: post.topic, user:) }

      let(:topic_url) { "#{Discourse.base_url}/t/#{post.topic.slug}/#{post.topic.id}" }

      def hreflang_links
        Nokogiri
          .HTML5(response.body)
          .css("link[rel='alternate'][hreflang]")
          .map { |link| [link["hreflang"], link["href"]] }
      end

      it "points each language alternate to the same page" do
        get "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=ja",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        expect(hreflang_links).to contain_exactly(
          ["x-default", "#{topic_url}?page=2"],
          ["en", "#{topic_url}?page=2"],
          ["ja", "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=ja"],
          ["es", "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=es"],
        )
      end

      it "keeps the page in the default locale's locale param URL when the plain URL may not serve the default locale" do
        SiteSetting.set_locale_from_cookie = true

        get "#{topic_url}?page=2",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        expect(hreflang_links).to include(
          ["x-default", "#{topic_url}?page=2"],
          ["en", "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=en"],
        )
      end

      it "keeps the locale param on the pagination link tags" do
        topic_path = post.topic.relative_url
        pagination_links = -> do
          Nokogiri
            .HTML5(response.body)
            .css("link[rel='prev'], link[rel='next']")
            .map { |link| [link["rel"], link["href"]] }
        end

        get "#{topic_url}?#{Discourse::LOCALE_PARAM}=ja",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        expect(pagination_links.call).to eq(
          [["next", "#{topic_path}?page=2&#{Discourse::LOCALE_PARAM}=ja"]],
        )

        get "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=ja",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        expect(pagination_links.call).to eq(
          [["prev", "#{topic_path}?#{Discourse::LOCALE_PARAM}=ja"]],
        )

        get "/latest?#{Discourse::LOCALE_PARAM}=ja",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        next_link = Nokogiri.HTML5(response.body).at_css("link[rel='next']")
        expect(Addressable::URI.parse(next_link["href"]).query_values).to include(
          "page" => "1",
          Discourse::LOCALE_PARAM => "ja",
        )
      end

      it "points the alternates of a reply link to the page that holds the reply" do
        get "#{topic_url}/#{replies.last.post_number}",
            headers: {
              "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
            }

        expect(hreflang_links).to include(
          ["x-default", "#{topic_url}?page=2"],
          ["ja", "#{topic_url}?page=2&#{Discourse::LOCALE_PARAM}=ja"],
        )
      end
    end

    it "includes the subfolder once in language alternates" do
      set_subfolder "/forum"

      get "/t/#{post.topic.slug}/#{post.topic.id}",
          env: {
            "SCRIPT_NAME" => "/forum",
          },
          headers: {
            "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)",
          }

      expect(response.body).to include(
        %(<link rel="alternate" href="#{Discourse.base_url_no_prefix}/forum/t/#{post.topic.slug}/#{post.topic.id}" hreflang="x-default" />),
      )
    end

    it "keeps language alternates on the forum when the topic canonicalizes to an embedding page on the same host" do
      SiteSetting.embed_set_canonical_url = true
      topic_embed = Fabricate(:topic_embed, post:, embed_url: "#{Discourse.base_url}/blog/article")
      topic_url = "#{Discourse.base_url}/t/#{post.topic.slug}/#{post.topic.id}"

      get topic_url, headers: { "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }

      expect(response.body).to include(
        %(<link rel="alternate" href="#{topic_url}?#{Discourse::LOCALE_PARAM}=ja" hreflang="ja" />),
      )
      expect(response.body).not_to include("#{topic_embed.embed_url}?#{Discourse::LOCALE_PARAM}=")
    end

    it "does not append ?tl= to canonical for non-crawler requests" do
      get "/t/#{post.topic.slug}/#{post.topic.id}?#{Discourse::LOCALE_PARAM}=ja"

      expect(response.body).to match(
        %r{<link rel="canonical" href="#{Regexp.escape(Discourse.base_url)}/t/#{post.topic.slug}/#{post.topic.id}"\s*/?>},
      )
    end
  end
end
