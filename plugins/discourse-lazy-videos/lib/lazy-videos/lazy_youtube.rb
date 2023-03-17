# frozen_string_literal: true

require "onebox"

class Onebox::Engine::YoutubeOnebox
  include Onebox::Engine
  alias_method :default_onebox_to_html, :to_html

  def to_html
    if SiteSetting.lazy_videos_enabled && SiteSetting.lazy_youtube_enabled && video_id &&
         !params["list"]
      result = parse_embed_response
      result ||= get_opengraph.data

      thumbnail_url = "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
      thumbnail_response = Net::HTTP.get_response(URI(thumbnail_url))
      thumbnail_url = result[:image] if !thumbnail_response.kind_of?(Net::HTTPSuccess)

      escaped_title = ERB::Util.html_escape(video_title)

      <<~HTML
        <div class="youtube-onebox lazy-video-container"
          data-video-id="#{video_id}"
          data-video-title="#{escaped_title}"
          data-provider-name="youtube">
          <a href="https://www.youtube.com/watch?v=#{video_id}" target="_blank">
            <img class="youtube-thumbnail"
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
