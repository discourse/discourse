# frozen_string_literal: true

module HasPostUploadReferences
  extend ActiveSupport::Concern

  def link_post_uploads(fragments: nil)
    upload_ids = []

    each_upload_url(fragments: fragments) do |url, _, sha1|
      upload = Upload.fetch_from(sha1:, url:)

      # Link any video thumbnails
      if SiteSetting.video_thumbnails_enabled && upload.present? &&
           FileHelper.supported_video.include?(upload.extension&.downcase)
        # Video thumbnails have the filename of the video file sha1 with a .png or .jpg extension.
        # This is because at time of upload in the composer we don't know the topic/post id yet
        # and there is no thumbnail info added to the markdown to tie the thumbnail to the topic/post after
        # creation.
        thumbnail =
          Upload
            .where("original_filename like ?", "#{upload.sha1}.%")
            .order(id: :desc)
            .first if upload.sha1.present?
        if thumbnail.present?
          upload_ids << thumbnail.id
          handle_video_thumbnail(thumbnail) if respond_to?(:handle_video_thumbnail, true)
        end
      end
      upload_ids << upload.id if upload.present?
    end

    upload_references =
      upload_ids.map do |upload_id|
        {
          target_id: self.id,
          target_type: self.class.name,
          upload_id: upload_id,
          created_at: Time.zone.now,
          updated_at: Time.zone.now,
        }
      end

    UploadReference.transaction do
      UploadReference.where(target: self).delete_all
      UploadReference.insert_all(upload_references) if upload_references.size > 0

      if SiteSetting.secure_uploads?
        Upload
          .where(id: upload_ids, access_control_post_id: nil)
          .where("id NOT IN (SELECT upload_id FROM custom_emojis)")
          .update_all(access_control_post_id: access_control_post_id_for_upload)
      end
    end
  end

  def each_upload_url(fragments: nil, include_local_upload: true)
    current_db = RailsMultisite::ConnectionManagement.current_db

    upload_patterns = [
      %r{/uploads/#{current_db}/},
      %r{/original/},
      %r{/optimized/},
      %r{/uploads/short-url/[a-zA-Z0-9]+(\.[a-z0-9]+)?},
    ]

    fragments ||= Nokogiri::HTML5.fragment(self.cooked)

    selectors =
      fragments.css(
        "a/@href",
        "img/@src",
        "source/@src",
        "track/@src",
        "video/@poster",
        "div/@data-video-src",
        "div/@data-original-video-src",
      )

    # Collect (src, path, sha1) tuples. Use data-base62-sha1 when available for unique
    # upload identification, even when multiple uploads share the same storage URL.
    seen_sha1s = Set.new
    upload_entries = []

    selectors.each do |media|
      src = media.value
      next if src.blank?

      # Handle lazy-loaded images with data-orig-src
      if src.end_with?("/images/transparent.png") &&
           (parent = media.parent)["data-orig-src"].present?
        src = parent["data-orig-src"]
      end

      src = src.split("?")[0]
      sha1 = nil
      path = nil

      # Check for data-base62-sha1 attribute which preserves unique upload identity
      # even when uploads share storage URLs (deduplication)
      parent = media.parent
      sha1_from_attribute =
        if parent && (base62 = parent["data-base62-sha1"]).present?
          Upload.sha1_from_base62(base62)
        end

      # Handle short URLs (upload:// or /uploads/short-url/) - these don't have extractable paths
      if src.start_with?("upload://")
        sha1 = sha1_from_attribute || Upload.sha1_from_short_url(src)
      elsif src.include?("/uploads/short-url/")
        host =
          begin
            URI(src).host
          rescue URI::Error
          end
        next if host.present? && host != Discourse.current_hostname
        sha1 = sha1_from_attribute || Upload.sha1_from_short_path(src)
      else
        # Regular URLs - extract path and optionally sha1
        next if upload_patterns.none? { |pattern| src =~ pattern }
        next if Rails.configuration.multisite && src.exclude?(current_db)

        src = "#{SiteSetting.force_https ? "https" : "http"}:#{src}" if src.start_with?("//")

        if !Discourse.store.has_been_uploaded?(src) && !Upload.secure_uploads_url?(src) &&
             !(include_local_upload && src =~ %r{\A/[^/]}i)
          next
        end

        path =
          begin
            URI(
              UrlHelper.unencode(GlobalSetting.cdn_url ? src.sub(GlobalSetting.cdn_url, "") : src),
            )&.path
          rescue URI::Error
          end

        next if path.blank?

        # Use sha1 from attribute if available, otherwise extract from path
        sha1 =
          sha1_from_attribute ||
            if path.include? "optimized"
              OptimizedImage.extract_sha1(path)
            else
              Upload.extract_sha1(path) || Upload.sha1_from_short_path(path)
            end
      end

      # Dedupe by sha1 to avoid duplicate references for the same upload
      next if sha1.present? && seen_sha1s.include?(sha1)
      seen_sha1s.add(sha1) if sha1.present?

      upload_entries << [src, path, sha1]
    end

    upload_entries.each { |src, path, sha1| yield(src, path, sha1) }
  end
end
