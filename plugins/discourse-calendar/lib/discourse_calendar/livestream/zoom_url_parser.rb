# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    module ZoomUrlParser
      # Matches zoom.us and its vanity subdomains (us06web.zoom.us), but not
      # hosts that merely end in those characters (notzoom.us, zoom.us.evil.com).
      SUPPORTED_HOST = /(\A|\.)zoom\.us\z/i
      SUPPORTED_PATH_SEGMENTS = %w[j w wc].freeze

      # The single source of truth for "is this a Zoom livestream URL we can
      # join?". A URL that parses is one the Meeting SDK can be handed.
      def self.zoom_url?(url)
        parse(url).present?
      end

      def self.parse(url)
        return if url.blank?

        uri = URI.parse(url)
        return if !uri.is_a?(URI::HTTPS) || uri.host.blank? || uri.host !~ SUPPORTED_HOST

        segments = uri.path.split("/").reject(&:blank?)
        segment_index = segments.find_index { |segment| SUPPORTED_PATH_SEGMENTS.include?(segment) }
        return if segment_index.blank?

        meeting_number = segments[segment_index + 1]
        return if meeting_number.blank? || !meeting_number.match?(/\A\d+\z/)

        password = Rack::Utils.parse_nested_query(uri.query.to_s)["pwd"]

        { meeting_number:, password: password.presence, url: uri.to_s }
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
