class AddVisibleBackToGroups < ActiveRecord::Migration[4.2]
  def change
    # add the visible column so it is delay dropped this cleans up some deploy issues
    add_column :groups, :visible, :boolean, default: true, null: false
    execute 'UPDATE groups set visible = false where visibility_level > 0'
  end
end
