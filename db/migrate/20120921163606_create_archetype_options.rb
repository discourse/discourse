class CreateArchetypeOptions < ActiveRecord::Migration[4.2]
  def change
    create_table :archetype_options do |t|
      t.references :archetype, null: false
      t.string :key, null: false
      t.integer :option_type, null: false
      t.timestamps null: false
    end

    add_index :archetype_options, :archetype_id

    execute "INSERT INTO archetype_options (archetype_id, key, option_type, created_at, updated_at)
              VALUES (2, 'private_poll', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
    execute "INSERT INTO archetype_options (archetype_id, key, option_type, created_at, updated_at)
              VALUES (2, 'single_vote', 1, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)"
  end
end
