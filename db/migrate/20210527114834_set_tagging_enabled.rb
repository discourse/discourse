# frozen_string_literal: true

class SetTaggingEnabled < ActiveRecord::Migration[6.1]
  def up
    result = execute('SELECT COUNT(*) FROM topics')

    # keep tagging disabled for existent sites
    if result.first['count'] > 0
      execute <<~SQL
        INSERT INTO site_settings(name, data_type, value, created_at, updated_at)
        VALUES('tagging_enabled', 5, 'f', NOW(), NOW())
        ON CONFLICT (name) DO NOTHING
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
