# frozen_string_literal: true

# name: discourse-lazy-videos
# about: Lazy loading for embedded videos
# version: 0.1
# authors: Jan Cernik
# url: https://github.com/discourse/discourse-lazy-videos

hide_plugin if self.respond_to?(:hide_plugin)
enabled_site_setting :lazy_videos_enabled

register_asset "stylesheets/lazy-videos.scss"

require_relative "lib/lazy-videos/lazy_youtube"
require_relative "lib/lazy-videos/lazy_vimeo"
require_relative "lib/lazy-videos/lazy_tiktok"

after_initialize do
  on(:reduce_cooked) do |fragment|
    fragment
      .css(".lazy-video-container a")
      .each do |video|
        href = video["href"]
        video.inner_html += "<p><a href=\"#{href}\">#{href}</a></p>"
      end
  end
end
