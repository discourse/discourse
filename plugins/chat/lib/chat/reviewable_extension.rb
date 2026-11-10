# frozen_string_literal: true

module Chat
  module ReviewableExtension
    extend ActiveSupport::Concern

    prepended { include TypeMappable }

    class_methods do
      def sti_class_mapping = { "ReviewableChatMessage" => Chat::ReviewableMessage }
      def polymorphic_class_mapping = { "ChatMessage" => Chat::Message }

      def viewable_by(user, ...)
        result = super
        return result if user.blank? || user.admin?

        allowed_category_ids = user.guardian.allowed_category_ids
        inaccessible_category_condition =
          if allowed_category_ids.empty?
            "TRUE"
          else
            "chat_channels.chatable_id NOT IN (:allowed_category_ids)"
          end

        result.where(
          <<~SQL,
          NOT EXISTS (
            SELECT 1
            FROM chat_messages
            INNER JOIN chat_channels ON chat_channels.id = chat_messages.chat_channel_id
            WHERE reviewables.type = :chat_reviewable_type
              AND chat_messages.id = reviewables.target_id
              AND chat_channels.chatable_type = 'Category'
              AND #{inaccessible_category_condition}
          )
        SQL
          chat_reviewable_type: Chat::ReviewableMessage.sti_name,
          allowed_category_ids:,
        )
      end
    end
  end
end
