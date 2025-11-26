# frozen_string_literal: true

class UploadSerializer < ApplicationSerializer
  attributes :id,
             :url,
             :original_filename,
             :filesize,
             :width,
             :height,
             :thumbnail_width,
             :thumbnail_height,
             :extension,
             :short_url,
             :short_path,
             :retain_hours,
             :human_filesize,
             :dominant_color

  has_one :thumbnail,
          serializer: UploadThumbnailSerializer,
          root: false,
          embed: :object,
          if: -> { SiteSetting.create_thumbnails && object.has_thumbnail? }

  has_one :optimized_video,
          serializer: OptimizedVideoSerializer,
          root: false,
          embed: :object,
          if: -> { SiteSetting.video_conversion_enabled && object.optimized_video.present? }

  def optimized_video
    object.optimized_videos.first
  end

  def url
    if object.for_site_setting
      object.url
    else
      UrlHelper.cook_url(object.url, secure: SiteSetting.secure_uploads? && object.secure)
    end
  end
end
