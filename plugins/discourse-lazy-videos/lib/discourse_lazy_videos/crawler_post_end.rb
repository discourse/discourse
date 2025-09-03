# frozen_string_literal: true

module DiscourseLazyVideos
  class CrawlerPostEnd
    attr_reader :controller, :post

    PROVIDER_NAMES = { "youtube" => "YouTube", "vimeo" => "Vimeo", "tiktok" => "TikTok" }.freeze

    def initialize(controller, post)
      @controller = controller
      @post = post
    end

    def html
      return "" if !controller.instance_of?(TopicsController)
      return "" if !SiteSetting.lazy_videos_enabled
      return "" if !post

      videos = extract_videos_from_post(post)
      return "" if videos.empty?

      videos
        .map do |video|
          schema = build_video_object(video, post)
          next if !schema

          json = MultiJson.dump(schema).gsub("</script", "<\\/script")
          "<script type=\"application/ld+json\">#{json}</script>"
        end
        .compact
        .join("\n")
    end

    private

    def extract_videos_from_post(post)
      videos = []
      doc = Nokogiri::HTML5.fragment(post.cooked)

      doc
        .css(".lazy-video-container")
        .each do |container|
          video_data = {
            provider: container["data-provider-name"],
            id: container["data-video-id"],
            title: container["data-video-title"],
            url: container.at_css("a")&.[]("href"),
            thumbnail: container.at_css("img")&.[]("src"),
          }

          videos << video_data if video_data[:provider] && video_data[:id]
        end

      videos
    end

    def build_video_object(video, post)
      embed_url = get_embed_url(video[:provider], video[:id])
      return nil if !embed_url

      schema = {
        "@context" => "https://schema.org",
        "@type" => "VideoObject",
        "name" => video[:title] || "#{PROVIDER_NAMES[video[:provider]] || video[:provider]} Video",
        "embedUrl" => embed_url,
        "url" => post.full_url,
        "uploadDate" => post.created_at.iso8601,
      }

      post_excerpt = post.excerpt(200, strip_links: true, text_entities: true)
      schema["description"] = post_excerpt if post_excerpt.present?

      schema["thumbnailUrl"] = video[:thumbnail] if video[:thumbnail]
      schema["contentUrl"] = video[:url] if video[:url]

      schema
    end

    def get_embed_url(provider, video_id)
      case provider
      when "youtube"
        Onebox::Engine::YoutubeOnebox.embed_url(video_id)
      when "vimeo"
        Onebox::Engine::VimeoOnebox.embed_url(video_id)
      when "tiktok"
        Onebox::Engine::TiktokOnebox.embed_url(video_id)
      else
        nil
      end
    end
  end
end
