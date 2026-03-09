# frozen_string_literal: true

module Onebox
  module Engine
    class VideoOnebox
      include Engine

      matches_regexp(%r{^(https?:)?//.*\.(mov|mp4|webm|ogv)(\?.*)?$}i)

      def always_https?
        AllowlistedGenericOnebox.host_matches(uri, AllowlistedGenericOnebox.https_hosts)
      end

      def to_html
        # Fix Dropbox video links - check format and transform accordingly
        url = @url
        if url[%r{^https://www.dropbox.com/s/}]
          # Old format: /s/xxxxx/file.mp4
          url = url.sub("https://www.dropbox.com", "https://dl.dropboxusercontent.com")
        elsif url[%r{^https://www.dropbox.com/scl/}]
          # New format: /scl/fi/xxxxx/file.mp4?rlkey=...
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
          <div class="onebox video-onebox">
            <video width='100%' height='100%' controls #{@options[:disable_media_download_controls] ? 'controlslist="nodownload"' : ""}>
              <source src='#{escaped_url}'>
              <a href='#{escaped_url}'>#{url}</a>
            </video>
          </div>
        HTML
      end

      def placeholder_html
        ::Onebox::Helpers.video_placeholder_html
      end
    end
  end
end
