module Onebox
  module Engine
    class AudioOnebox
      include Engine

      matches_regexp(/^(https?:)?\/\/.*\.(mp3|ogg|wav|m4a)(\?.*)?$/i)

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
      end

      def to_html
        url = ::Onebox::Helpers.normalize_url_for_output(@url)
        "<audio controls><source src='#{url}'><a href='#{url}'>#{url}</a></audio>"
      end
    end
  end
end
