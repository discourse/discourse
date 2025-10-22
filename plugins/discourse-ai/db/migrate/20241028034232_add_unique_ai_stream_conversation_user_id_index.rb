# frozen_string_literal: true
class AddUniqueAiStreamConversationUserIdIndex < ActiveRecord::Migration[7.1]
  def change
    add_index :user_custom_fields,
              [:value],
              unique: true,
              where: "name = 'ai-stream-conversation-unique-id'"
  end
end
