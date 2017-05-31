class AddThemes < ActiveRecord::Migration
  def up
    rename_table :site_customizations, :themes

    add_column :themes, :user_selectable, :bool, null: false, default: false
    add_column :themes, :hidden, :bool, null: false, default: false
    add_column :themes, :color_scheme_id, :integer

    create_table :child_themes do |t|
      t.integer :parent_theme_id
      t.integer :child_theme_id
      t.timestamps
    end

    add_index :child_themes, [:parent_theme_id, :child_theme_id], unique: true
    add_index :child_themes, [:child_theme_id, :parent_theme_id], unique: true

    # versioning in color scheme table was very confusing, remove it
    execute "DELETE FROM color_schemes WHERE versioned_id IS NOT NULL"
    remove_column :color_schemes, :versioned_id

    enabled_theme_count = execute("SELECT count(*) FROM themes WHERE enabled")
        .to_a[0]["count"].to_i


    enabled_scheme_id = execute("SELECT id FROM color_schemes WHERE enabled")
        .to_a[0]&.fetch("id")

    theme_key, theme_id =
      execute("SELECT key, id FROM themes WHERE enabled").to_a[0]&.values

    if (enabled_theme_count == 0  && enabled_scheme_id) || enabled_theme_count > 1

      puts "Creating a new default theme!"

      theme_key = '7e202ef2-6666-47d5-98d8-a9c8d15e57dd'

      sql = <<SQL
      INSERT INTO themes(name,created_at,updated_at, enabled, key, user_id)
      VALUES('Default', :now, :now, false, :key, -1)
      RETURNING *
SQL

      sql = ActiveRecord::Base.sql_fragment(sql, now: Time.zone.now, key: theme_key)
      theme_id = execute(sql).to_a[0]["id"].to_i
    end

    if enabled_theme_count > 1
      execute <<SQL
      INSERT INTO child_themes(parent_theme_id, child_theme_id, created_at, updated_at)
      SELECT #{theme_id.to_i}, id, created_at, updated_at
      FROM themes WHERE enabled
SQL
    end

    if enabled_scheme_id
      execute "UPDATE themes SET color_scheme_id=#{enabled_scheme_id.to_i} WHERE id=#{theme_id.to_i}"
    end

    if enabled_scheme_id || (enabled_theme_count > 0)
      puts "Setting default theme"
      sql = <<SQL
      INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
      VALUES('default_theme_key', 1, :key, :now, :now)
SQL
      sql = ActiveRecord::Base.sql_fragment(sql, now: Time.zone.now, key: theme_key)
      execute(sql)
    end



    remove_column :themes, :enabled
    remove_column :color_schemes, :enabled
  end

  def down
    raise IrriversibleMigration
  end
end
