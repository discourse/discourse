# frozen_string_literal: true
class AddIndexToPostActions < ActiveRecord::Migration[7.2]
  def change
    add_index :post_actions, :deleted_by_id, where: "deleted_by_id IS NOT NULL"
    add_index :post_actions, :deferred_by_id, where: "deferred_by_id IS NOT NULL"
    add_index :post_actions, :agreed_by_id, where: "agreed_by_id IS NOT NULL"
    add_index :post_actions, :disagreed_by_id, where: "disagreed_by_id IS NOT NULL"
  end
end
