module Onebox
  module Engine
    class ImageOnebox
      include Engine

      matches_regexp(/^(https?:)?\/\/.+\.(png|jpg|jpeg|gif|bmp|tif|tiff)(\?.*)?$/i)

      def always_https?
        WhitelistedGenericOnebox.host_matches(uri, WhitelistedGenericOnebox.https_hosts)
      end

      def to_html
        # Fix Dropbox image links
        if /^https:\/\/www.dropbox.com\/s\//.match @url
          @url.gsub!("https://www.dropbox.com","https://dl.dropboxusercontent.com")
        end

        escaped = Onebox::Helpers.normalize_url_for_output(url)
        "<a href='#{escaped}' target='_blank'><img src='#{escaped}'></a>"
      end
    end
  end
end
