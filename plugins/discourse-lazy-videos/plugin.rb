# frozen_string_literal: true

# name: discourse-lazy-videos
# about: Lazy loading for embedded videos
# version: 0.1
# authors: Jan Cernik
# url: https://github.com/discourse/discourse-lazy-videos

hide_plugin
enabled_site_setting :lazy_videos_enabled

register_asset "stylesheets/lazy-videos.scss"

require_relative "lib/lazy-videos/lazy_youtube"
require_relative "lib/lazy-videos/lazy_vimeo"
require_relative "lib/lazy-videos/lazy_tiktok"

after_initialize do
  on(:reduce_cooked) do |fragment|
    fragment
      .css(".lazy-video-container")
      .each do |video|
        title = video["data-video-title"]
        href = video.at_css("a")["href"]
        video.replace("<p><a href=\"#{href}\">#{title}</a></p>")
      end
  end
end
