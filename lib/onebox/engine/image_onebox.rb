# frozen_string_literal: true

module Onebox
  module Engine
    class ImageOnebox
      include Engine

      matches_content_type(%r{^image/(png|jpg|jpeg|gif|bmp|tif|tiff|webp|avif)$})
      matches_regexp(%r{^(https?:)?//.+\.(png|jpg|jpeg|gif|bmp|tif|tiff|webp|avif)(\?.*)?$}i)

      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts)
      end

      def to_html
        # Fix Dropbox image links - check format and transform accordingly
        url = @url
        if url[%r{^https://www.dropbox.com/s/}]
          # Old format: /s/xxxxx/file.png
          url = url.sub("https://www.dropbox.com", "https://dl.dropboxusercontent.com")
        elsif url[%r{^https://www.dropbox.com/scl/}]
          # New format: /scl/fi/xxxxx/file.png?rlkey=...
          # Transform to dl domain and ensure raw=1 parameter
          uri = URI.parse(url)
          params = URI.decode_www_form(uri.query || "").to_h
          params["raw"] = "1" unless params["raw"] == "1"
          uri.query = URI.encode_www_form(params)
          uri.host = "dl.dropboxusercontent.com"
          url = uri.to_s
        end

        escaped_url = ::Onebox::Helpers.normalize_url_for_output(url)
        <<-HTML
          <a href="#{escaped_url}" target="_blank" rel="noopener" class="onebox">
            <img src="#{escaped_url}">
          </a>
        HTML
      end
    end
  end
end
