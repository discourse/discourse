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
        if @url[/^https:\/\/www.dropbox.com\/s\//]
          @url.sub!("https://www.dropbox.com", "https://dl.dropboxusercontent.com")
        end

        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)

        <<-HTML
          <a href="#{escaped_url}" target="_blank">
            <img src="#{escaped_url}">
          </a>
        HTML
      end
    end
  end
end
