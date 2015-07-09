module Onebox
  module Engine
    class AudioOnebox
      include Engine

      matches_regexp /^(https?:)?\/\/.*\.(mp3|ogg|wav)(\?.*)?$/

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
      end

      def to_html
        "<audio controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></audio>"
      end
    end
  end
end
