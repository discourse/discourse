class AddPublicToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :public, :boolean, default: :false, null: false
  end
end
