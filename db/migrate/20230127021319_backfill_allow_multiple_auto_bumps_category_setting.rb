# frozen_string_literal: true

class BackfillAllowMultipleAutoBumpsCategorySetting < ActiveRecord::Migration[7.0]
  def up
    execute <<~'SQL'
      INSERT INTO category_custom_fields (category_id, name, value, created_at, updated_at)
      SELECT id, 'allow_multiple_auto_bumps', 't', NOW(), NOW()
      FROM categories
      ON CONFLICT DO NOTHING;
    SQL
  end

  def down
    execute <<~'SQL'
      DELETE FROM category_custom_fields
      WHERE name = 'allow_multiple_auto_bumps';
    SQL
  end
end
