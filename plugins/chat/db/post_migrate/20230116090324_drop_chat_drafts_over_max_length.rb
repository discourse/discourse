# frozen_string_literal: true

class DropChatDraftsOverMaxLength < ActiveRecord::Migration[7.0]
  def up
    if table_exists?(:chat_drafts)
      # Delete abusive drafts
      execute <<~SQL
        DELETE FROM chat_drafts
        WHERE LENGTH(data) > 50000
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
