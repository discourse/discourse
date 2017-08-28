class SplitAliasLevels < ActiveRecord::Migration
  def up
    add_column :groups, :messageable_level, :integer, default: 0
    add_column :groups, :mentionable_level, :integer, default: 0

    execute 'UPDATE groups SET messageable_level = alias_level, mentionable_level = alias_level'
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
