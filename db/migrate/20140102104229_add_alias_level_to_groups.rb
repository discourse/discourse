class AddAliasLevelToGroups < ActiveRecord::Migration
  def change
    add_column :groups, :alias_level, :integer, default: 0
  end
end
