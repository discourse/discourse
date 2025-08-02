# frozen_string_literal: true

class AddNotNullsToUserOpenIds < ActiveRecord::Migration[4.2]
  def change
    change_column :user_open_ids, :user_id, :integer, null: false
    change_column :user_open_ids, :email, :string, null: false
    change_column :user_open_ids, :url, :string, null: false
  end
end
