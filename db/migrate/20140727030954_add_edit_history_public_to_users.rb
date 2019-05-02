# frozen_string_literal: true

class AddEditHistoryPublicToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :edit_history_public, :boolean, default: false, null: false
  end
end
