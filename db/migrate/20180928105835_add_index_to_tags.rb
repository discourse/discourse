class AddIndexToTags < ActiveRecord::Migration[5.2]
  def up
    # Append ID to any tags that already have duplicate names
    # Super rare case, as this is not possible to do via the UI
    # Might affect some imports
    execute <<~SQL
      UPDATE tags
      SET name = name || id
      WHERE EXISTS(SELECT * FROM tags t WHERE lower(t.name) = lower(tags.name) AND t.id < tags.id)
    SQL

    add_index :tags, 'lower(name)', unique: true
  end
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
