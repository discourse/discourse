# frozen_string_literal: true

# name: discourse-lazy-videos
# about: Lazy loading for embedded videos
# version: 0.1
# authors: Jan Cernik
# url: https://github.com/discourse/discourse/blob/main/plugins/discourse-lazy-videos

enabled_site_setting :lazy_videos_enabled

register_svg_icon "bed"
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
        link = fragment.document.create_element("a")
        link["href"] = video.at_css("a")["href"].to_s
        link.add_child(fragment.document.create_text_node(video["data-video-title"].to_s))

        paragraph = fragment.document.create_element("p")
        paragraph.add_child(link)
        video.replace(paragraph)
      end
  end
end
