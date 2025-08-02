# frozen_string_literal: true

class ChangeSegmentCjkSiteSetting < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
    UPDATE site_settings
    SET name = 'search_tokenize_chinese'
    WHERE name = 'search_tokenize_chinese_japanese_korean'
    SQL

    execute <<~SQL
    DELETE FROM site_settings
    WHERE name = 'search_tokenize_chinese_japanese_korean'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
