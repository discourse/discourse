# frozen_string_literal: true

module Chat
  module CategoryExtension
    extend ActiveSupport::Concern

    include Chat::Chatable

    def self.polymorphic_name
      Chat::Chatable.polymorphic_name_for(self) || super
    end

    prepended do
      has_one :category_channel,
              as: :chatable,
              class_name: "Chat::CategoryChannel",
              dependent: :destroy
    end

    def cannot_delete_reason
      return I18n.t("category.cannot_delete.has_chat_channels") if category_channel
      super
    end

    def deletable_for_chat?
      return true if !category_channel
      category_channel.chat_messages_empty?
    end
  end
end
