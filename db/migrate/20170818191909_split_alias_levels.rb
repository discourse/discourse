class SplitAliasLevels < ActiveRecord::Migration
  def change
    rename_column :groups, :alias_level, :mentionable_level
    add_column :groups, :messageable_level, :integer, default: 0

    Group.update_all('messageable_level=mentionable_level')
  end
end
