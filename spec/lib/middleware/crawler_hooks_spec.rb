# frozen_string_literal: true

describe Middleware::CrawlerHooks do
  let(:crawler_user_agent) { "GoogleBot/2.1 (+https://www.google.com/bot.html)" }
  let(:regular_user_agent) { "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" }
  let(:html_response) do
    html_arr = [
      "<html><body><a href=\"/test\">Test</a><a href=\"https://discourse.org/page\">External</a></body></html>",
    ]
    def html_arr.body
      join("")
    end
    html_arr
  end

  let(:middleware) { Middleware::CrawlerHooks.new(app) }
  let(:app) do
    lambda do |env|
      headers = { "Content-Type" => "text/html; charset=utf-8" }
      headers["X-Discourse-Crawler-View"] = "true" if env["X-Discourse-Crawler-View"]
      [200, headers, html_response]
    end
  end
  let(:json_middleware) do
    Middleware::CrawlerHooks.new(
      lambda do |_|
        [200, { "Content-Type" => "application/json; charset=utf-8" }, ['{ "key": "value" }']]
      end,
    )
  end
  let(:error_middleware) do
    Middleware::CrawlerHooks.new(
      lambda do |_|
        [
          404,
          { "Content-Type" => "text/html; charset=utf-8" },
          ["<html><body>Not found</body></html>"],
        ]
      end,
    )
  end

  def env(opts = {})
    path = opts.delete(:path) || "https://discourse.site"
    params = opts.delete(:params) || {}
    Rack::MockRequest.env_for(path, params: params).merge(opts)
  end

  before do
    SiteSetting.content_localization_enabled = false
    SiteSetting.content_localization_crawler_param = false
  end

  describe "handling regular users" do
    it "does not modify responses for non-crawler requests" do
      status, headers, response = middleware.call(env("HTTP_USER_AGENT" => regular_user_agent))

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("text/html")
      expect(response).to eq(html_response)
    end
  end

  describe "handling crawler requests" do
    it "does not modify responses without X-Discourse-Crawler-View header" do
      status, headers, response = middleware.call(env("HTTP_USER_AGENT" => crawler_user_agent))

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("text/html")
      expect(response).to eq(html_response)
    end

    it "does not modify responses for non-HTML content types" do
      status, headers, response = json_middleware.call(env("HTTP_USER_AGENT" => crawler_user_agent))

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("application/json")
      expect(response).to eq(['{ "key": "value" }'])
    end

    it "does not modify responses for non-200 status codes" do
      status, headers, response =
        error_middleware.call(env("HTTP_USER_AGENT" => crawler_user_agent))

      expect(status).to eq(404)
      expect(response).to eq(["<html><body>Not found</body></html>"])
    end

    it "does not modify HTML responses when content_localization is disabled" do
      SiteSetting.content_localization_enabled = false
      SiteSetting.content_localization_crawler_param = true

      status, headers, response =
        middleware.call(
          env(
            :path => "https://discourse.site",
            :params => {
              "locale" => "fr",
            },
            "HTTP_USER_AGENT" => crawler_user_agent,
            "X-Discourse-Crawler-View" => true,
          ),
        )

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("text/html")
      expect(response).to eq(html_response)
    end

    it "does not modify HTML responses when crawler_param is disabled" do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = false

      status, headers, response =
        middleware.call(
          env(
            :path => "https://discourse.site",
            :params => {
              "locale" => "fr",
            },
            "HTTP_USER_AGENT" => crawler_user_agent,
            "X-Discourse-Crawler-View" => true,
          ),
        )

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("text/html")
      expect(response).to eq(html_response)
    end

    it "appends locale parameter to links in HTML responses when both settings are enabled and crawler header present" do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = true

      # Create a real request with parameters
      test_env =
        Rack::MockRequest.env_for(
          "https://discourse.site/page",
          params: {
            Discourse::LOCALE_PARAM => "fr",
          },
        )
      request = Rack::Request.new(test_env)

      # Create our middleware and test response transformation
      middleware_instance =
        Middleware::CrawlerHooks.new(
          lambda { |_| [200, { "X-Discourse-Crawler-View" => "true" }, []] },
        )
      response = html_response

      transformed_response =
        middleware_instance.send(:transform_response, request: request, response: response)

      expect(transformed_response).not_to eq(html_response)
      expect(transformed_response.first).to include("href=\"/test?#{Discourse::LOCALE_PARAM}=fr\"")
      expect(transformed_response.first).to include("href=\"https://discourse.org/page\"")
      expect(Nokogiri::HTML5.parse(transformed_response.first).css("a").size).to eq(2)
    end

    it "does not modify links in HTML responses when locale parameter is not present" do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = true

      status, headers, response =
        middleware.call(
          env(
            :path => "https://discourse.site",
            "HTTP_USER_AGENT" => crawler_user_agent,
            "X-Discourse-Crawler-View" => true,
          ),
        )

      expect(status).to eq(200)
      expect(headers["Content-Type"]).to include("text/html")
      expect(response).to eq(html_response)
    end

    it "modifies external links that start with the base URL" do
      SiteSetting.content_localization_enabled = true
      SiteSetting.content_localization_crawler_param = true

      base_url = Discourse.base_url
      html_with_base_url = ["<html><body><a href=\"#{base_url}/cat\">Cats</a></body></html>"]
      def html_with_base_url.body
        join("")
      end

      test_env =
        Rack::MockRequest.env_for(
          "https://discourse.site",
          params: {
            Discourse::LOCALE_PARAM => "fr",
          },
        )
      request = Rack::Request.new(test_env)

      middleware_instance =
        Middleware::CrawlerHooks.new(
          lambda { |_| [200, { "X-Discourse-Crawler-View" => "true" }, []] },
        )

      transformed_response =
        middleware_instance.send(
          :transform_response,
          request: request,
          response: html_with_base_url,
        )

      expect(transformed_response.first).to include(
        "href=\"#{base_url}/cat?#{Discourse::LOCALE_PARAM}=fr\"",
      )
    end
  end
end
