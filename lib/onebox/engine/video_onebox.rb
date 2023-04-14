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
        # Fix Dropbox image links
        if @url[%r{^https://www.dropbox.com/s/}]
          @url.sub!("https://www.dropbox.com", "https://dl.dropboxusercontent.com")
        end

        escaped_url = ::Onebox::Helpers.normalize_url_for_output(@url)
        <<-HTML
          <div class="onebox video-onebox">
            <video width='100%' height='100%' controls #{@options[:disable_media_download_controls] ? 'controlslist="nodownload"' : ""}>
              <source src='#{escaped_url}'>
              <a href='#{escaped_url}'>#{@url}</a>
            </video>
          </div>
        HTML
      end

      def placeholder_html
        SiteSetting.enable_diffhtml_preview ? to_html : ::Onebox::Helpers.video_placeholder_html
      end
    end
  end
end
