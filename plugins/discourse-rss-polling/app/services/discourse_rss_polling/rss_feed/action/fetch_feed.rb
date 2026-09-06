# frozen_string_literal: true

require "rss"

module DiscourseRssPolling
  class RssFeed
    module Action
      class FetchFeed < Service::ActionBase
        Result = Struct.new(:items, :error, keyword_init: true)

        option :feed_url

        def call
          raw_feed = fetch_raw_feed

          if raw_feed.blank?
            Rails.logger.warn("RSS Polling: Failed to fetch feed from #{redacted_url}")
            return Result.new(items: [], error: :fetch_failed)
          end

          parsed_feed = RSS::Parser.parse(raw_feed, false)

          if parsed_feed.blank?
            Rails.logger.warn("RSS Polling: Unable to parse feed from #{redacted_url}")
            return Result.new(items: [], error: :parse_failed)
          end

          Result.new(items: parsed_feed.items.map { |item| FeedItem.new(item) }, error: nil)
        rescue RSS::Error => e
          Discourse.warn_exception(e, message: "RSS Polling: Invalid RSS from #{redacted_url}")
          Result.new(items: [], error: :invalid_feed)
        rescue => e
          Discourse.warn_exception(
            e,
            message: "RSS Polling: Failed to fetch feed from #{redacted_url}",
          )
          Result.new(items: [], error: :fetch_failed)
        end

        private

        def url
          @url ||= feed_url.to_s.strip
        end

        def redacted_url
          @redacted_url ||= FeedUrl.redact(url)
        end

        def fetch_raw_feed
          request_url, headers = extract_api_credentials(url)
          body = +""
          response_status = nil

          fd =
            FinalDestination.new(
              request_url,
              headers:,
              timeout: SiteSetting.rss_polling_feed_request_timeout,
            )

          fd.get do |response, chunk, uri|
            if uri.blank? || !response.is_a?(Net::HTTPSuccess)
              response_status = response&.code
              throw :done
            end
            body << chunk
          end

          if body.blank? && response_status.present?
            Rails.logger.warn(
              "RSS Polling: HTTP #{response_status} when fetching #{redacted_url} (status: #{fd.status})",
            )
          end

          body.presence
        end

        def extract_api_credentials(request_url)
          clean_url, credentials = FeedUrl.split_credentials(request_url)
          api_key, api_username = credentials.values_at("api_key", "api_username")

          return request_url, {} if api_key.blank?

          headers = { "Api-Key" => api_key }
          headers["Api-Username"] = api_username if api_username.present?

          [clean_url, headers]
        end
      end
    end
  end
end
