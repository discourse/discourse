# frozen_string_literal: true
class AddIndexToTagGroups < ActiveRecord::Migration[8.0]
  def up
    # Same from /db/migrate/20180928105835_add_index_to_tags.rb
    execute <<~SQL
      UPDATE tag_groups
      SET name = name || id
      WHERE EXISTS(SELECT * FROM tag_groups t WHERE lower(t.name) = lower(tag_groups.name) AND t.id < tag_groups.id)
    SQL

    add_index :tag_groups, "lower(name)", unique: true
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
