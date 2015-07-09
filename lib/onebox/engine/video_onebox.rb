module Onebox
  module Engine
    class VideoOnebox
      include Engine

      matches_regexp /^(https?:)?\/\/.*\.(mov|mp4|webm|ogv)(\?.*)?$/

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
      end

      def to_html
        "<video width='100%' height='100%' controls><source src='#{@url}'><a href='#{@url}'>#{@url}</a></video>"
      end
    end
  end
end
