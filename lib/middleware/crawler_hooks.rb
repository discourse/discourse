# frozen_string_literal: true

module Middleware
  class CrawlerHooks
    NON_LOCALIZABLE_PATH_PREFIXES = %w[/uploads/ /secure-uploads/ /secure-media-uploads/].freeze

    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, response = @app.call(env)

      if status == 200 && headers["X-Discourse-Crawler-View"] &&
           headers["Content-Type"]&.include?("text/html") &&
           !non_localizable_path?(request_path_without_base_path(request)) &&
           ContentLocalization.crawler_locale_param_enabled?
        response = transform_response(request:, response:)
      end

      [status, headers, response]
    end

    private

    def transform_response(request:, response:)
      locale = request.params[Discourse::LOCALE_PARAM]

      if ContentLocalization.crawler_locale_param_enabled? && locale.present?
        html_fragment = Nokogiri::HTML5.parse(response.body)

        html_fragment
          .css("a[href^='/'], a[href^='#{Discourse.base_url}']")
          .each do |link|
            uri = Addressable::URI.parse(link["href"])
            next if non_localizable_path?(uri.path)
            uri.query_values = (uri.query_values || {}).merge(Discourse::LOCALE_PARAM => locale)
            link["href"] = uri.to_s
          end

        transformed_html = html_fragment.to_html
        return [transformed_html || response]
      end

      response
    end

    def non_localizable_path?(path)
      return false if path.blank?
      NON_LOCALIZABLE_PATH_PREFIXES.any? { |prefix| path.start_with?(prefix) }
    end

    def request_path_without_base_path(request)
      path = request.path
      base_path = Discourse.base_path

      if base_path.present? && path.start_with?(base_path)
        path.delete_prefix(base_path)
      else
        path
      end
    end
  end
end
