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

    def self.normalize_src(src, reset_scheme: true)
      uri = Addressable::URI.heuristic_parse(src)
      uri.normalize!
      uri.scheme = nil if reset_scheme
      uri.to_s
    rescue URI::Error, Addressable::URI::InvalidURIError
      src
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
#
