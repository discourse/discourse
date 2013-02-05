class CreateArchetypes < ActiveRecord::Migration
  def up
    create_table :archetypes do |t|
      t.string :name_key, null: false
      t.timestamps
    end
    add_index :archetypes, :name_key, unique: true

    execute "INSERT INTO archetypes (name_key, created_at, updated_at) VALUES ('regular', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    execute "INSERT INTO archetypes (name_key, created_at, updated_at) VALUES ('poll', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"

    add_column :forum_threads, :archetype_id, :integer, default: 1, null: false
  end

  def down
    remove_column :forum_threads, :archetype_id
    drop_table :archetypes
  end

end
