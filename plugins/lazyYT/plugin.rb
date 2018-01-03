# name: lazyYT
# about: Uses the lazyYT plugin to lazy load Youtube videos
# version: 1.0.1
# authors: Arpit Jalan
# url: https://github.com/discourse/discourse/tree/master/plugins/lazyYT

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

  Email::Styles.register_plugin_style do |fragment|
    # YouTube onebox can't go in emails, so replace them with clickable links
    fragment.css('.lazyYT').each do |i|
      begin
        src = "https://www.youtube.com/embed/#{i['data-youtube-id']}?autoplay=1&#{i['data-parameters']}"
        src_uri = URI(src)
        display_src = "https://#{src_uri.host}#{src_uri.path}"
        i.replace "<p><a href='#{src_uri.to_s}'>#{display_src}</a><p>"
      rescue URI::InvalidURIError
        # If the URL is weird, remove it
        i.remove
      end
    end
  end
end
