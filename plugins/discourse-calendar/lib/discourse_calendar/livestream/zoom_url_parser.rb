# frozen_string_literal: true

module DiscourseCalendar
  module Livestream
    module ZoomUrlParser
      SUPPORTED_HOST = /(^|\.)zoom\.us\z/
      SUPPORTED_PATH_SEGMENTS = %w[j w wc].freeze

      def self.parse(url)
        return if url.blank?

        uri = URI.parse(url)
        return if !uri.is_a?(URI::HTTP) || uri.host.blank? || uri.host !~ SUPPORTED_HOST

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
