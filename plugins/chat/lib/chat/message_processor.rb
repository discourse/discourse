# frozen_string_literal: true

module Chat
  class MessageProcessor
    include ::CookedProcessorMixin
    IMG_FILETYPES = %w[jpg jpeg gif png heic heif webp]

    attr_reader :used_hotlinked_media_ids

    def initialize(chat_message, opts = {})
      @model = chat_message
      @previous_cooked = (chat_message.cooked || "").dup
      @should_secure_uploads = false
      @size_cache = {}
      @opts = opts
      @used_hotlinked_media_ids = Set.new

      cook_opts = {
        user_id: chat_message.last_editor_id,
        author_username: chat_message.user&.username,
      }
      cook_opts[:invalidate_oneboxes] = true if opts[:invalidate_oneboxes] == true
      cooked = Chat::Message.cook(chat_message.message, **cook_opts)
      @doc = Loofah.html5_fragment(cooked)
    end

    def run!
      post_process_oneboxes
      process_hotlinked_images
      process_thumbnails
      post_process_videos
      add_lightbox_to_images
      DiscourseEvent.trigger(:chat_message_processed, @doc, @model)
    end

    # Unlike posts, chat keeps the hotlinked src when a download fails or is too large.
    def process_hotlinked_image(img)
      normalized_src =
        Chat::MessageHotlinkedMedia.normalize_src(HotlinkedMedia.download_src_for(img))
      info = hotlinked_media_map[normalized_src]
      used_hotlinked_media_ids << info.id if info

      if info&.downloaded? && (upload = info.upload)
        img["src"] = UrlHelper.cook_url(upload.url, secure: upload.secure?)
        img["data-base62-sha1"] = upload.base62_sha1
        img["data-dominant-color"] = upload.dominant_color(calculate_if_missing: true).presence
        img.delete(PrettyText::BLOCKED_HOTLINKED_SRC_ATTR)
      end

      true
    end

    def process_hotlinked_images
      extract_images.each { |img| process_hotlinked_image(img) }
    end

    def process_thumbnails
      return if !SiteSetting.create_thumbnails

      @model.uploads.each do |upload|
        next if upload.blank? || IMG_FILETYPES.exclude?(upload.extension&.downcase)

        if upload.width <= SiteSetting.max_image_width &&
             upload.height <= SiteSetting.max_image_height
          return false
        end

        crop =
          SiteSetting.min_ratio_to_crop > 0 &&
            upload.width.to_f / upload.height.to_f < SiteSetting.min_ratio_to_crop

        width = upload.thumbnail_width
        height = upload.thumbnail_height

        # create the main thumbnail
        upload.create_thumbnail!(width, height, crop: crop)

        # create additional responsive thumbnails
        each_responsive_ratio do |ratio|
          resized_w = (width * ratio).to_i
          resized_h = (height * ratio).to_i

          if upload.width && resized_w <= upload.width
            upload.create_thumbnail!(resized_w, resized_h, crop: crop)
          end
        end
      end
    end

    def add_lightbox_to_images
      @doc
        .css("img")
        .each do |img|
          if img["class"]&.include?("emoji") || img["class"]&.include?("avatar") ||
               img["data-base62-sha1"].blank? || img.ancestors(".onebox, .onebox-body").any?
            next
          end

          sha1 = Upload.sha1_from_base62_encoded(img["data-base62-sha1"])
          if upload = Upload.find_by(sha1: sha1)
            img["data-large-src"] = UrlHelper.cook_url(upload.url, secure: upload.secure?)
            img["data-download-href"] = upload.short_path
            img["data-target-width"] = upload.width
            img["data-target-height"] = upload.height
            img["class"] = "#{img["class"]} lightbox".strip
          end
        end
    end

    def hotlinked_media_map
      @hotlinked_media_map ||= @model.hotlinked_media.preload(:upload).index_by(&:url)
    end

    def large_images
      []
    end

    def broken_images
      []
    end

    def downloaded_images
      {}
    end

    def post_process_videos
      changes_made = false

      begin
        @doc
          .css(".video-placeholder-container")
          .each do |container|
            src = container["data-video-src"]
            next if src.blank?

            # Look for optimized video
            upload = Upload.get_from_url(src)
            if upload && optimized_video = OptimizedVideo.find_by(upload_id: upload.id)
              optimized_url = Discourse.store.cdn_url(optimized_video.optimized_upload.url)
              # Only update if the URL is different
              if container["data-video-src"] != optimized_url
                container["data-original-video-src"] = container["data-video-src"] unless container[
                  "data-original-video-src"
                ]
                container["data-video-src"] = optimized_url
                changes_made = true
              end
              # Ensure we maintain reference to original upload and optimized upload
              UploadReference.ensure_exist!(
                upload_ids: [upload.id, optimized_video.optimized_upload.id],
                target: @model,
              )
            end
          end

        # Handle video tags with source elements (for direct video uploads in cooked HTML)
        @doc
          .css("video.chat-video-upload source, video source")
          .each do |source|
            src = source["src"]
            next if src.blank?

            # Look for optimized video
            upload = Upload.get_from_url(src)
            if upload && optimized_video = OptimizedVideo.find_by(upload_id: upload.id)
              optimized_url = Discourse.store.cdn_url(optimized_video.optimized_upload.url)
              # Only update if the URL is different
              if source["src"] != optimized_url
                source["data-original-src"] = source["src"] unless source["data-original-src"]
                source["src"] = optimized_url
                changes_made = true
              end
              # Ensure we maintain reference to original upload and optimized upload
              UploadReference.ensure_exist!(
                upload_ids: [upload.id, optimized_video.optimized_upload.id],
                target: @model,
              )
            end
          end

        # Also check uploads directly associated with the message
        @model.uploads.each do |upload|
          next unless FileHelper.is_supported_video?(upload.original_filename)

          if optimized_video = OptimizedVideo.find_by(upload_id: upload.id)
            # Ensure we maintain reference to optimized upload
            UploadReference.ensure_exist!(
              upload_ids: [optimized_video.optimized_upload.id],
              target: @model,
            )
          end
        end

        # Update the chat message's cooked content if changes were made
        if changes_made
          new_cooked = @doc.to_html
          @model.cooked = new_cooked
          if !@model.save
            Rails.logger.error(
              "Failed to save chat message: #{@model.errors.full_messages.join(", ")}",
            )
          end
        end
      rescue => e
        Rails.logger.error("Error in post_process_videos for chat message: #{e.message}")
        Rails.logger.error(e.backtrace.join("\n"))
      end
    end
  end
end
