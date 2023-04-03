# frozen_string_literal: true

require "onebox"

class Onebox::Engine::VimeoOnebox
  include Onebox::Engine
  alias_method :default_onebox_to_html, :to_html

  def to_html
    if SiteSetting.lazy_videos_enabled && SiteSetting.lazy_vimeo_enabled
      full_video_id = oembed_data[:uri].sub("/videos/", "").sub(":", "/")

      if !oembed_data[:uri].match?(%r{videos/\d+:.+})
        iframe_id = full_video_id
      else
        iframe_src = Nokogiri::HTML5.fragment(oembed_data[:html]).at_css("iframe")&.[]("src")
        iframe_id = iframe_src.sub("https://player.vimeo.com/video/", "")
      end

      thumbnail_url = "https://vumbnail.com/#{oembed_data[:video_id]}.jpg"
      puts thumbnail_url
      escaped_title = ERB::Util.html_escape(og_data.title)

      <<~HTML
        <div class="vimeo-onebox lazy-video-container"
          data-video-id="#{iframe_id}"
          data-video-title="#{escaped_title}"
          data-provider-name="vimeo">
          <a href="https://vimeo.com/#{full_video_id}" target="_blank">
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
