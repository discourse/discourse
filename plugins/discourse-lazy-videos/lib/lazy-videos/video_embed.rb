# frozen_string_literal: true

module LazyVideos
  class VideoEmbed
    def self.transform_lazy_video_containers(html_document)
      transform_lazy_youtube_container(html_document)
      transform_lazy_vimeo_container(html_document)
      transform_lazy_tiktok_container(html_document)
      html_document
    end

    private

    def self.transform_lazy_youtube_container(html_document)
      html_document
        .css("div.youtube-onebox.lazy-video-container")
        .each do |container|
          video_id = container["data-video-id"]
          next if video_id.blank?

          video_title = container["data-video-title"]
          start_time = container["data-video-start-time"]
          embed_params = "feature=oembed&wmode=opaque"
          thumbnail_url = "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg"
          video_url = "https://www.youtube.com/watch?v=#{video_id}"
          video_url += "&t=#{start_time}" if start_time.present?
          embed_url = "https://www.youtube.com/embed/#{video_id}?#{embed_params}"

          metadata = {
            name: video_title,
            description: video_title,
            embed_url: embed_url,
            content_url: video_url,
            thumbnail_url: thumbnail_url,
          }

          video_object_wrapper = create_video_object(metadata)
          container.replace(video_object_wrapper)
        end

      html_document
    end

    def self.transform_lazy_vimeo_container(html_document)
      html_document
        .css("div.vimeo-onebox.lazy-video-container")
        .each do |container|
          video_id = container["data-video-id"]
          next if video_id.blank?

          video_title = container["data-video-title"]
          embed_url = "https://player.vimeo.com/video/#{video_id}"
          video_url = "https://vimeo.com/#{video_id}"
          thumbnail_url = "https://vumbnail.com/#{video_id}.jpg"

          metadata = {
            name: video_title,
            description: video_title,
            embed_url: embed_url,
            content_url: video_url,
            thumbnail_url: thumbnail_url,
          }

          video_object_wrapper = create_video_object(metadata)
          container.replace(video_object_wrapper)
        end

      html_document
    end

    def self.transform_lazy_tiktok_container(html_document)
      html_document
        .css("div.tiktok-onebox.lazy-video-container")
        .each do |container|
          video_id = container["data-video-id"]
          next if video_id.blank?

          video_title = container["data-video-title"]
          embed_url = "https://www.tiktok.com/embed/v2/#{video_id}"
          video_url = "https://www.tiktok.com/video/#{video_id}"

          # we can't reliably generate thumbnail URLs directly
          thumbnail_url = "https://www.tiktok.com/api/img/?itemId=#{video_id}&location=0"

          metadata = {
            name: video_title,
            description: video_title,
            embed_url: embed_url,
            content_url: video_url,
            thumbnail_url: thumbnail_url,
          }

          video_object_wrapper = create_video_object(metadata)
          container.replace(video_object_wrapper)
        end

      html_document
    end

    def self.create_video_object(metadata)
      video_object =
        Nokogiri::HTML5.fragment(
          '<div itemscope itemtype="https://schema.org/VideoObject"></div>',
        ).at("div")

      if metadata[:name].present?
        video_object.add_child("<meta itemprop=\"name\" content=\"#{metadata[:name]}\">")
      end
      if metadata[:description].present?
        video_object.add_child(
          "<meta itemprop=\"description\" content=\"#{metadata[:description]}\">",
        )
      end

      if metadata[:thumbnail_url].present?
        video_object.add_child(
          "<meta itemprop=\"thumbnailUrl\" content=\"#{metadata[:thumbnail_url]}\">",
        )

        video_object.add_child(
          "<a href=\"#{metadata[:content_url]}\" target=\"_blank\" rel=\"noopener noreferrer\">" +
            "<img itemprop=\"thumbnail\" src=\"#{metadata[:thumbnail_url]}\" " +
            "alt=\"#{metadata[:name]}\" style=\"max-width: 100%; height: auto;\">" + "</a>",
        )
      end

      if metadata[:embed_url].present?
        video_object.add_child("<meta itemprop=\"embedUrl\" content=\"#{metadata[:embed_url]}\">")
      end
      video_object.add_child(
        "<meta itemprop=\"uploadDate\" content=\"#{Time.now.strftime("%Y-%m-%d")}\">",
      )
      if metadata[:content_url].present?
        video_object.add_child(
          "<meta itemprop=\"contentUrl\" content=\"#{metadata[:content_url]}\">",
        )
      end

      video_object
    end
  end
end
