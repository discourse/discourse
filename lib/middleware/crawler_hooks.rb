# frozen_string_literal: true

module Middleware
  class CrawlerHooks
    NON_LOCALIZABLE_PATH_PREFIXES = %w[/uploads/ /secure-uploads/ /secure-media-uploads/].freeze
    # Anchors, plus the pagination link tags, which crawlers follow like anchors.
    LOCALIZABLE_LINK_TAGS = %w[a link[rel='prev'] link[rel='next']].freeze

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
      # Set by the controller when the page's tags use the plain URL for the default locale.
      plain_url =
        locale == SiteSetting.default_locale &&
          request.env[ContentLocalization::PLAIN_URL_SERVES_DEFAULT_LOCALE_ENV]

      if ContentLocalization.crawler_locale_param_enabled? && locale.present? && !plain_url
        html_fragment = Nokogiri::HTML5.parse(response.body)

        html_fragment
          .css(localizable_link_selector)
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

    def localizable_link_selector
      LOCALIZABLE_LINK_TAGS
        .product(["/", Discourse.base_url])
        .map { |tag, prefix| "#{tag}[href^='#{prefix}']" }
        .join(", ")
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
