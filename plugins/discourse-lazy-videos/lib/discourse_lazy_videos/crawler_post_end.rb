# frozen_string_literal: true

module DiscourseLazyVideos
  class CrawlerPostEnd
    attr_reader :controller, :post

    PROVIDER_NAMES = { "youtube" => "YouTube", "vimeo" => "Vimeo", "tiktok" => "TikTok" }.freeze
    SCRIPT_ESCAPE_REGEX = %r{</script}i.freeze
    LAZY_VIDEO_CONTAINER = "lazy-video-container"

    def initialize(controller, post)
      @controller = controller
      @post = post
    end

    def html
      return "" if !controller.instance_of?(TopicsController)
      return "" if !SiteSetting.lazy_videos_enabled
      return "" if !post
      return "" if post.cooked.exclude?(LAZY_VIDEO_CONTAINER)

      generate_video_schemas
    end

    private

    def generate_video_schemas
      videos = extract_videos_from_post(post)
      return "" if videos.empty?

      @post_excerpt ||= post.excerpt(200, strip_links: true, text_entities: true)

      videos
        .each_with_object([]) do |video, scripts|
          schema = build_video_object(video, post, @post_excerpt)
          next if !schema

          scripts << build_json_script(schema)
        end
        .join("\n")
    end

    def extract_videos_from_post(post)
      @parsed_doc ||= Nokogiri::HTML5.fragment(post.cooked)
      videos = []

      @parsed_doc
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

    def build_video_object(video, post, post_excerpt)
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

      schema["description"] = post_excerpt if post_excerpt.present?
      schema["thumbnailUrl"] = video[:thumbnail] if video[:thumbnail]
      schema["contentUrl"] = video[:url] if video[:url]

      schema
    end

    def build_json_script(schema)
      json = MultiJson.dump(schema).gsub(SCRIPT_ESCAPE_REGEX, "<\\/script")
      "<script type=\"application/ld+json\">#{json}</script>"
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
