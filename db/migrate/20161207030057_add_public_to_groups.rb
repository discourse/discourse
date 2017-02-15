class AddPublicToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :public, :boolean, default: :false, null: false
  end
end
