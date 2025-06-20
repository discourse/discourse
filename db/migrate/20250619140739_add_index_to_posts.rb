# frozen_string_literal: true
class AddIndexToPosts < ActiveRecord::Migration[7.2]
  def change
    add_index :posts, :deleted_by_id, where: "deleted_by_id IS NOT NULL"
    add_index :posts, :last_editor_id, where: "last_editor_id IS NOT NULL"
    add_index :posts, :locked_by_id, where: "locked_by_id IS NOT NULL"
    add_index :posts, :reply_to_user_id, where: "reply_to_user_id IS NOT NULL"
  end
end
