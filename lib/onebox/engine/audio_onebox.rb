# frozen_string_literal: true

module Onebox
  module Engine
    class AudioOnebox
      include Engine

      matches_regexp(/^(https?:)?\/\/.*\.(mp3|ogg|opus|wav|m4a)(\?.*)?$/i)

      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts)
      end

      def to_html
        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)

        <<-HTML
          <audio controls>
            <source src="#{escaped_url}">
            <a href="#{escaped_url}">#{@url}</a>
          </audio>
        HTML
      end

      def placeholder_html
        ::Onebox::Helpers.audio_placeholder_html
      end
    end
  end
end
