class EnableSidebar < ActiveRecord::Migration[7.0]
  def up
    # keep sidebar legacy disabled for existing sites
    execute <<~SQL if Migration::Helpers.existing_site?
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('navigation_menu', 7, 'legacy', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
