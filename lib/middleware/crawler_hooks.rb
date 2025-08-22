# frozen_string_literal: true

module Middleware
  class CrawlerHooks
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, response = @app.call(env)

      if status == 200 && headers["X-Discourse-Crawler-View"] &&
           SiteSetting.content_localization_enabled &&
           SiteSetting.content_localization_crawler_param
        response = transform_response(request:, response:)
      end

      [status, headers, response]
    end

    private

    def transform_response(request:, response:)
      locale = request.params[Discourse::LOCALE_PARAM]

      if SiteSetting.content_localization_enabled &&
           SiteSetting.content_localization_crawler_param && locale.present?
        html_fragment = Nokogiri::HTML5.parse(response.body)

        html_fragment
          .css("a[href^='/'], a[href^='#{Discourse.base_url}']")
          .each do |link|
            uri = Addressable::URI.parse(link["href"])
            uri.query_values = (uri.query_values || {}).merge(Discourse::LOCALE_PARAM => locale)
            link["href"] = uri.to_s
          end

        transformed_html = html_fragment.to_html
        return [transformed_html || response]
      end

      response
    end
  end
end
