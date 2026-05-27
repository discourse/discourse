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
          if: -> { SiteSetting.video_conversion_enabled && include_optimized_video? }

  def optimized_video
    # Use association if loaded to avoid N+1 queries
    if object.association(:optimized_videos).loaded?
      object.optimized_videos.first
    else
      # If association not loaded, only query if we know it exists
      nil
    end
  end

  def include_optimized_video?
    # Only include if association is already loaded to avoid N+1 queries
    # Callers should eager load optimized_videos when serializing multiple uploads
    object.association(:optimized_videos).loaded? && object.optimized_videos.first.present?
  end

  def url
    if object.for_site_setting
      object.url
    else
      UrlHelper.cook_url(object.url, secure: SiteSetting.secure_uploads? && object.secure)
    end
  end
end
