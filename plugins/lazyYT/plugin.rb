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

  def to_html
    if video_id
      # Put in the LazyYT div instead of the iframe
      "<div class=\"lazyYT\" data-youtube-id=\"#{video_id}\" data-width=\"480\" data-height=\"270\" data-parameters=\"#{embed_params}\"></div>"
    else
      super
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
