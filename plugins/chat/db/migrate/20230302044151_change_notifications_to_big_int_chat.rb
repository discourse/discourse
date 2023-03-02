# frozen_string_literal: true

class ChangeNotificationsToBigIntChat < ActiveRecord::Migration[7.0]
  disable_ddl_transaction!

  def up
    change_column :chat_mentions, :notification_id, :bigint
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
