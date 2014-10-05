class AddDefaultToActive < ActiveRecord::Migration
  def change
    change_column :users, :active, :boolean, default: false, null: false
  end
end
