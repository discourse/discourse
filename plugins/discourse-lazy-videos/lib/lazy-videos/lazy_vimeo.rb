# frozen_string_literal: true

require "onebox"

class Onebox::Engine::VimeoOnebox
  include Onebox::Engine
  alias_method :default_onebox_to_html, :to_html

  def to_html
    if SiteSetting.lazy_videos_enabled && SiteSetting.lazy_vimeo_enabled
      video_id = oembed_data[:video_id]
      thumbnail_url = "https://vumbnail.com/#{oembed_data[:video_id]}.jpg"
      escaped_title = ERB::Util.html_escape(og_data.title)
      video_url = "https://vimeo.com/#{video_id}"

      <<~HTML
        <div class="vimeo-onebox lazy-video-container"
          data-video-id="#{video_id}"
          data-video-title="#{escaped_title}"
          data-video-url="#{video_url}"
          data-provider-name="vimeo">
          <a href="#{video_url}" target="_blank">
            <img class="vimeo-thumbnail"
              src="#{thumbnail_url}"
              title="#{escaped_title}">
          </a>
        </div>
      HTML
    else
      default_onebox_to_html
    end
  end
end
