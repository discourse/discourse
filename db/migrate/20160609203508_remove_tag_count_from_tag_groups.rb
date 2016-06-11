class RemoveTagCountFromTagGroups < ActiveRecord::Migration
  def change
    remove_column :tag_groups, :tag_count
  end
end
