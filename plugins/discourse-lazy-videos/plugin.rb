# frozen_string_literal: true

# name: discourse-lazy-videos
# about: Lazy loading for embedded videos
# version: 0.1
# authors: Jan Cernik
# url: https://github.com/discourse/discourse-lazy-videos

enabled_site_setting :lazy_videos_enabled

register_asset "stylesheets/lazy-videos.scss"

module ::DiscourseLazyVideos
end

require_relative "lib/discourse_lazy_videos/lazy_youtube"
require_relative "lib/discourse_lazy_videos/lazy_vimeo"
require_relative "lib/discourse_lazy_videos/lazy_tiktok"
require_relative "lib/discourse_lazy_videos/crawler_post_end"

after_initialize do
  register_html_builder("server:topic-show-crawler-post-end") do |controller, post:|
    DiscourseLazyVideos::CrawlerPostEnd.new(controller, post).html
  end

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
