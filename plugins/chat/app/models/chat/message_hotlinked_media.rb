# frozen_string_literal: true

module Chat
  class MessageHotlinkedMedia < ActiveRecord::Base
    self.table_name = "chat_message_hotlinked_media"

    belongs_to :chat_message, class_name: "Chat::Message"
    belongs_to :upload, optional: true

    enum :status,
         {
           downloaded: "downloaded",
           too_large: "too_large",
           download_failed: "download_failed",
           upload_create_failed: "upload_create_failed",
         },
         scopes: false

    class << self
      def normalize_src(src, reset_scheme: true)
        PostHotlinkedMedia.normalize_src(src, reset_scheme: reset_scheme)
      end
    end

    # Whether the pull job would fetch +src+. The cook consults this too, to
    # decide whether handing the message to that job is worth a job slot.
    def self.downloadable?(src)
      return false if src.blank?
      return false if !SiteSetting.download_remote_images_to_local?
      return false if !SiteSetting.chat_allow_uploads?
      return false if src.downcase.start_with?("data:")
      # Host-agnostic on purpose: the downloader signs our own S3 path for any
      # URL shaped like this, whoever serves it. Posts gate that on the author
      # seeing the access-control post; chat messages have none, so there is
      # nothing to authorize against.
      return false if Upload.secure_uploads_url?(src)

      if !HotlinkedMedia.remote_src?(src)
        return false if src !~ %r{/uploads/}
        # pass nil: chat messages have no access-control post to reuse against
        return !Upload.consider_for_reuse(Upload.get_from_url(src), nil).present?
      end

      begin
        uri = URI.parse(src)
      rescue URI::Error
        return false
      end
      return false if uri.hostname.blank?

      SiteSetting.should_download_images?(src)
    end
  end
end

# == Schema Information
#
# Table name: chat_message_hotlinked_media
#
#  id              :bigint           not null, primary key
#  status          :string           not null
#  url             :string           not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  chat_message_id :bigint           not null
#  upload_id       :bigint
#
# Indexes
#
#  index_chat_message_hotlinked_media_on_message_and_url_md5  (chat_message_id, md5((url)::text)) UNIQUE
#  index_chat_message_hotlinked_media_on_upload_id            (upload_id)
#
