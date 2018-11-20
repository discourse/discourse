class ConvertArchetypes < ActiveRecord::Migration[4.2]
  def up
    add_column :forum_threads, :archetype, :string, default: 'regular', null: false
    execute "UPDATE forum_threads SET archetype = a.name_key FROM archetypes AS a WHERE a.id = forum_threads.archetype_id"
    remove_column :forum_threads, :archetype_id

    drop_table :archetypes
    drop_table :archetype_options
  end

  def down
    remove_column :forum_threads, :archetype
  end
end
