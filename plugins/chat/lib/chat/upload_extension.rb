# frozen_string_literal: true

module Chat
  module UploadExtension
    extend ActiveSupport::Concern

    prepended do
      has_many :chat_message_hotlinked_media,
               class_name: "Chat::MessageHotlinkedMedia",
               dependent: :destroy
    end
  end
end
