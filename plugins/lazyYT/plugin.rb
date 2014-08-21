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
      html = "<div class=\"lazyYT\" data-youtube-id=\"#{video_id}\" data-width=\"480\" data-height=\"270\" data-parameters=\"start=0\"></div>"
    else
      # Fall back to making HTTP requests.
      html = raw[:html] || ""
    end

    rewrite_agnostic(append_params(html))
  end

  def append_params(html)
    result = html.dup
    result.gsub! /(src="[^"]+)/, '\1&wmode=opaque'
    if url =~ /t=(\d+h)?(\d+m)?(\d+s?)?/
      h = Regexp.last_match[1].to_i
      m = Regexp.last_match[2].to_i
      s = Regexp.last_match[3].to_i

      total = (h * 60 * 60) + (m * 60) + s
      start_time = "\"start=#{total}\""

      result.gsub!('"start=0"', start_time)
    end
    result
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
