class AddVisibileToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :visible, :boolean, default: true, null: false
  end
end
