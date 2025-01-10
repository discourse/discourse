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

      begin
        Onebox::Helpers.fetch_response(thumbnail_url)
      rescue StandardError
        thumbnail_url = result[:image]
      end

      return default_onebox_to_html if video_title.chomp("- YouTube").blank? || thumbnail_url.blank?

      escaped_title = ERB::Util.html_escape(video_title)
      escaped_start_time = ERB::Util.html_escape(params["t"])
      t_param = "&t=#{escaped_start_time}" if escaped_start_time.present?

      <<~HTML
        <div class="youtube-onebox lazy-video-container"
          data-video-id="#{video_id}"
          data-video-title="#{escaped_title}"
          data-video-start-time="#{escaped_start_time}"
          data-provider-name="youtube">
          <a href="https://www.youtube.com/watch?v=#{video_id}#{t_param}" target="_blank" class="video-thumbnail">
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
