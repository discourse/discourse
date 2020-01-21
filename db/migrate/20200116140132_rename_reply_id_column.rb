# frozen_string_literal: true

class RenameReplyIdColumn < ActiveRecord::Migration[6.0]
  def up
    add_column :post_replies, :reply_post_id, :integer

    execute <<~SQL
      UPDATE post_replies
      SET reply_post_id = reply_id
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
