# frozen_string_literal: true

module Onebox
  module Engine
    class AudioOnebox
      include Engine

      matches_regexp(/^(https?:)?\/\/.*\.(mp3|ogg|opus|wav|m4a)(\?.*)?$/i)

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
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
        "<div class='onebox-placeholder-container'><span class='placeholder-icon audio'></span></div>"
      end
    end
  end
end
