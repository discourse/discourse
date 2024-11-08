# frozen_string_literal: true

module Chat
  class MessageProcessor
    include ::CookedProcessorMixin
    IMG_FILETYPES = %w[jpg jpeg gif png heic heif webp].freeze

    def initialize(chat_message, opts = {})
      @model = chat_message
      @previous_cooked = (chat_message.cooked || "").dup
      @should_secure_uploads = false
      @size_cache = {}
      @opts = opts

      cooked = Chat::Message.cook(chat_message.message, user_id: chat_message.last_editor_id)
      @doc = Loofah.html5_fragment(cooked)
    end

    def run!
      post_process_oneboxes
      process_thumbnails
      DiscourseEvent.trigger(:chat_message_processed, @doc, @model)
    end

    def process_thumbnails
      return if !SiteSetting.create_thumbnails

      @model.uploads.each do |upload|
        next if upload.blank? || IMG_FILETYPES.exclude?(upload.extension.downcase)

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

    def large_images
      []
    end

    def broken_images
      []
    end

    def downloaded_images
      {}
    end
  end
end
