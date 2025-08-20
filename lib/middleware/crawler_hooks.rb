# frozen_string_literal: true

module Middleware
  class CrawlerHooks
    def initialize(app)
      @app = app
    end

    def call(env)
      request = Rack::Request.new(env)
      status, headers, response = @app.call(env)

      if status == 200 && headers["Content-Type"]&.include?("text/html") &&
           CrawlerDetection.crawler?(request.user_agent, request.get_header("HTTP_VIA"))
        response = transform_response(response)
      end

      [status, headers, response]
    end

    private

    def transform_response(original_response)
      body = original_response.body

      # there's an opportunity for a "string" transformer here
      # if the nokogiri fragment is not needed

      has_fragment_transformers =
        DiscoursePluginRegistry.crawler_html_fragment_transformations.present?
      return original_response unless has_fragment_transformers

      if has_fragment_transformers
        html_fragment = Nokogiri::HTML5.parse(body)

        DiscoursePluginRegistry.crawler_html_fragment_transformations.each do |transformer|
          transformer.call(html_fragment)
        end

        transformed_html = html_fragment.to_html
      end

      [transformed_html || original_response]
    end
  end
end
