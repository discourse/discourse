# frozen_string_literal: true

require "rss"

module DiscourseRssPolling
  class FeedFetcher
    Result = Struct.new(:items, :error, keyword_init: true)

    def initialize(feed_url)
      @feed_url = feed_url.to_s.strip
    end

    def fetch
      raw_feed = fetch_raw_feed

      if raw_feed.blank?
        Rails.logger.warn("RSS Polling: Failed to fetch feed from #{@feed_url}")
        return Result.new(items: [], error: :fetch_failed)
      end

      parsed_feed = RSS::Parser.parse(raw_feed, false)

      if parsed_feed.blank?
        Rails.logger.warn("RSS Polling: Unable to parse feed from #{@feed_url}")
        return Result.new(items: [], error: :parse_failed)
      end

      items = parsed_feed.items.map { |item| FeedItem.new(item) }
      Result.new(items:, error: nil)
    rescue RSS::Error => e
      Discourse.warn_exception(e, message: "RSS Polling: Invalid RSS from #{@feed_url}")
      Result.new(items: [], error: :invalid_feed)
    end

    private

    def fetch_raw_feed
      url, headers = extract_api_credentials(@feed_url)
      body = +""

      fd =
        FinalDestination.new(url, headers:, timeout: SiteSetting.rss_polling_feed_request_timeout)
      response_status = nil

      fd.get do |response, chunk, uri|
        if uri.blank? || !response.is_a?(Net::HTTPSuccess)
          response_status = response&.code
          throw :done
        end
        body << chunk
      end

      if body.blank? && response_status.present?
        Rails.logger.warn(
          "RSS Polling: HTTP #{response_status} when fetching #{@feed_url} (status: #{fd.status})",
        )
      end

      body.presence
    end

    def extract_api_credentials(url)
      uri = URI.parse(url)
      return url, {} if uri.query.blank?

      params = CGI.parse(uri.query)
      api_key = params.delete("api_key")&.first
      api_username = params.delete("api_username")&.first

      return url, {} if api_key.blank?

      headers = { "Api-Key" => api_key }
      headers["Api-Username"] = api_username if api_username.present?

      uri.query = params.empty? ? nil : URI.encode_www_form(params)
      [uri.to_s, headers]
    end
  end
end
