# frozen_string_literal: true

class AddAdminFlagToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
    add_column :users, :moderator, :boolean, default: false, null: false
  end
end
