# frozen_string_literal: true

module Onebox
  module Engine
    class ImageOnebox
      include Engine

      matches_content_type(%r{^image/(png|jpg|jpeg|gif|bmp|tif|tiff)$})
      matches_regexp(%r{^(https?:)?//.+\.(png|jpg|jpeg|gif|bmp|tif|tiff)(\?.*)?$}i)

      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts)
      end

      def to_html
        # Fix Dropbox image links
        if @url[%r{^https://www.dropbox.com/s/}]
          @url.sub!("https://www.dropbox.com", "https://dl.dropboxusercontent.com")
        end

        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)
        <<-HTML
          <a href="#{escaped_url}" target="_blank" rel="noopener" class="onebox">
            <img src="#{escaped_url}">
          </a>
        HTML
      end
    end
  end
end
