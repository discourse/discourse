class AddAliasLevelToGroups < ActiveRecord::Migration[4.2]
  def change
    add_column :groups, :alias_level, :integer, default: 0
  end
end
