# frozen_string_literal: true

# name: lazy-yt
# about: Uses the lazyYT plugin to lazy load Youtube videos
# version: 1.0.1
# authors: Arpit Jalan
# url: https://github.com/discourse/discourse/tree/master/plugins/lazy-yt

hide_plugin if self.respond_to?(:hide_plugin)

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
      video_width = (params['width'] && params['width'].to_i <= 695) ? params['width'] : 480 # embed width
      video_height = (params['height'] && params['height'].to_i <= 500) ? params['height'] : 270 # embed height

      # Put in the LazyYT div instead of the iframe
      escaped_title = ERB::Util.html_escape(video_title)
      "<div class=\"lazyYT\" data-youtube-id=\"#{video_id}\" data-youtube-title=\"#{escaped_title}\" data-width=\"#{video_width}\" data-height=\"#{video_height}\" data-parameters=\"#{embed_params}\"></div>"
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
