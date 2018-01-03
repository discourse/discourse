class AddSchemaMigrationDetails < ActiveRecord::Migration[4.2]
  def up
    # schema_migrations table is way too thin, does not give info about
    # duration of migration or the date it happened, this migration together with the
    # monkey patch adds a lot of information to the migration table

    create_table :schema_migration_details do |t|
      t.string :version, null: false
      t.string :name
      t.string :hostname
      t.string :git_version
      t.string :rails_version
      t.integer :duration
      t.string :direction # this really should be a pg enum type but annoying to wire up for little gain
      t.datetime :created_at, null: false
    end

    add_index :schema_migration_details, [:version]

    execute("INSERT INTO schema_migration_details(version, created_at)
             SELECT version, current_timestamp
             FROM schema_migrations
             ORDER BY version
            ")
  end

  def down
    drop_table :schema_migration_details
  end
end
