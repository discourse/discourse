# frozen_string_literal: true

class AddUserDeletedToPosts < ActiveRecord::Migration[4.2]
  def change
    add_column :posts, :user_deleted, :boolean, null: false, default: false
  end
end
