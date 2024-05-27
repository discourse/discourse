# frozen_string_literal: true

class MakeChatMentionNotificationIdNullable < ActiveRecord::Migration[7.0]
  def up
    change_column_null :chat_mentions, :notification_id, true
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
