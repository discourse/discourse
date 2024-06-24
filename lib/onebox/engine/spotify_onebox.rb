# frozen_string_literal: true

module Onebox
  module Engine
    class SpotifyOnebox
      include Engine
      include StandardEmbed

      matches_regexp(%r{^https?://open\.spotify/\.com})
      requires_iframe_origins "https://open.spotify.com"
      always_https

      def to_html
        oembed = get_oembed
        oembed.html
      end

      def placeholder_html
        oembed = get_oembed
        return if oembed.thumbnail_url.blank?
        "<img src='#{oembed.thumbnail_url}' title='#{oembed.title}' alt='#{oembed.title}' height='#{oembed.thumbnail_height}' width='#{oembed.thumbnail_width}'>"
      end

      protected

      def get_oembed_url
        "https://open.spotify.com/oembed?url=#{url}"
      end
    end
  end
end
