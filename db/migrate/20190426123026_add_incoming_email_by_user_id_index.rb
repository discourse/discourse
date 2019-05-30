# frozen_string_literal: true

class AddIncomingEmailByUserIdIndex < ActiveRecord::Migration[5.2]
  def change
    add_index :incoming_emails, [:user_id], where: 'user_id IS NOT NULL'
  end
end
