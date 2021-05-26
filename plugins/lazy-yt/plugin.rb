# frozen_string_literal: true

# name: lazy-yt
# about: Uses the lazyYT plugin to lazy load Youtube videos
# version: 1.0.1
# authors: Arpit Jalan
# url: https://github.com/discourse/discourse/tree/master/plugins/lazy-yt

hide_plugin if self.respond_to?(:hide_plugin)

require "onebox"

# javascript
register_asset "javascripts/lazyYT.js"

# stylesheet
register_asset "stylesheets/lazyYT.css"
register_asset "stylesheets/lazyYT_mobile.scss", :mobile

# freedom patch YouTube Onebox
class Onebox::Engine::YoutubeOnebox
  include Onebox::Engine
  alias_method :yt_onebox_to_html, :to_html

  def to_html
    if video_id && !params['list']

      size_restricted = [params['width'], params['height']].any?
      video_width = (params['width'] && params['width'].to_i <= 695) ? params['width'] : 690 # embed width
      video_height = (params['height'] && params['height'].to_i <= 500) ? params['height'] : 388 # embed height
      size_tags = ["width=\"#{video_width}\"", "height=\"#{video_height}\""]

      result = parse_embed_response
      result ||= get_opengraph.data

      thumbnail_url = result[:image] || "https://img.youtube.com/vi/#{video_id}/hqdefault.jpg"

      # Put in the LazyYT div instead of the iframe
      escaped_title = ERB::Util.html_escape(video_title)

      <<~EOF
      <div class="onebox lazyYT lazyYT-container"
           data-youtube-id="#{video_id}"
           data-youtube-title="#{escaped_title}"
           #{size_restricted ? size_tags.map { |t| "data-#{t}" }.join(' ') : ""}
           data-parameters="#{embed_params}">
        <a href="https://www.youtube.com/watch?v=#{video_id}" target="_blank">
          <img class="ytp-thumbnail-image"
               src="#{thumbnail_url}"
               #{size_restricted ? size_tags.join(' ') : ""}
               title="#{escaped_title}">
        </a>
      </div>
      EOF
    else
      yt_onebox_to_html
    end
  end

end

after_initialize do

  on(:reduce_cooked) do |fragment|
    fragment.css(".lazyYT").each do |yt|
      begin
        youtube_id = yt["data-youtube-id"]
        parameters = yt["data-parameters"]
        uri = URI("https://www.youtube.com/embed/#{youtube_id}?autoplay=1&#{parameters}")
        yt.replace %{<p><a href="#{uri.to_s}">https://#{uri.host}#{uri.path}</a></p>}
      rescue URI::InvalidURIError
        # remove any invalid/weird URIs
        yt.remove
      end
    end
  end

end
