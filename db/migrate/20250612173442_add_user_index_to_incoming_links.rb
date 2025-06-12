# frozen_string_literal: true

class AddUserIndexToIncomingLinks < ActiveRecord::Migration[7.2]
  def change
    add_index :incoming_links, :user_id, where: "user_id IS NOT NULL"
    add_index :incoming_links, :current_user_id, where: "current_user_id IS NOT NULL"
  end
end
