class AddStagedToUser < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :staged, :boolean, null: false, default: false
  end
end
