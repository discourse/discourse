# name: lazyYT
# about: Uses the lazyYT plugin to lazy load Youtube videos
# version: 0.1
# authors: Arpit Jalan

# javascript
register_asset "javascripts/lazyYT.js"

# stylesheet
register_asset "stylesheets/lazyYT.css"
register_asset "stylesheets/lazyYT_mobile.scss", :mobile

# freedom patch YouTube Onebox
class Onebox::Engine::YoutubeOnebox
  include Onebox::Engine

  def to_html
    if video_id
      # Avoid making HTTP requests if we are able to get the video ID from the
      # URL.
      html = "<div class=\"lazyYT\" data-youtube-id=\"#{video_id}\" data-width=\"480\" data-height=\"270\"></div>"
    else
      # Fall back to making HTTP requests.
      html = raw[:html] || ""
    end

    rewrite_agnostic(append_params(html))
  end
end
