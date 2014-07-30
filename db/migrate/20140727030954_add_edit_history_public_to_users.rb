class AddEditHistoryPublicToUsers < ActiveRecord::Migration
  def change
    add_column :users, :edit_history_public, :boolean, default: false, null: false
  end
end
