# frozen_string_literal: true

module DiscourseAi
  module Rag
    class WebPageFetcher
      MAX_RESPONSE_BODY_LENGTH = 5.megabytes
      SUPPORTED_CONTENT_TYPES = %w[text/html application/xhtml+xml text/plain].freeze

      FetchError = Class.new(StandardError)

      def self.fetch(url:, etag: nil, last_modified: nil)
        new(url:, etag:, last_modified:).fetch
      end

      def initialize(url:, etag:, last_modified:)
        @url = url
        @etag = etag
        @last_modified = last_modified
      end

      def fetch
        result = nil

        DiscourseAi::Agents::Tools::Tool.send_http_request(
          @url,
          headers: request_headers,
          follow_redirects: true,
        ) { |response, resolved_uri| result = build_result(response, resolved_uri) }

        result || raise(FetchError, "The page could not be fetched")
      rescue FinalDestination::SSRFError, SocketError, URI::InvalidURIError => error
        raise FetchError, error.message
      end

      private

      def request_headers
        {}.tap do |headers|
          headers["If-None-Match"] = @etag if @etag.present?
          headers["If-Modified-Since"] = @last_modified if @last_modified.present?
        end
      end

      def build_result(response, resolved_uri)
        return { not_modified: true } if response.code == "304"

        raise FetchError, "The page returned HTTP #{response.code}" if response.code != "200"

        content_type = response["Content-Type"].to_s.split(";", 2).first
        if content_type.present? && SUPPORTED_CONTENT_TYPES.exclude?(content_type)
          raise FetchError, "Unsupported content type: #{content_type}"
        end

        body =
          DiscourseAi::Agents::Tools::Tool.read_response_body(
            response,
            max_length: MAX_RESPONSE_BODY_LENGTH,
          )
        text = content_type == "text/plain" ? body : extract_html(body)
        raise FetchError, "The page did not contain readable text" if text.blank?

        {
          not_modified: false,
          url: resolved_uri&.to_s || @url,
          text: text,
          etag: response["ETag"],
          last_modified: response["Last-Modified"],
        }
      end

      def extract_html(html)
        document = Nokogiri.HTML5(html)
        document.search("script, style, noscript, template").remove

        main_content =
          document.at("article") || document.at("main") || document.at("[role='main']") ||
            document.at("#main") || document.at(".main") || document.at("#content") ||
            document.at(".content") || document.at("body")

        main_content&.xpath(".//text()")&.map(&:text)&.join(" ").to_s.gsub(/\s+/, " ").strip
      end
    end
  end
end
