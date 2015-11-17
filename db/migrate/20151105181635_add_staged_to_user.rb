class AddStagedToUser < ActiveRecord::Migration
  def change
    add_column :users, :staged, :boolean, null: false, default: false
  end
end
