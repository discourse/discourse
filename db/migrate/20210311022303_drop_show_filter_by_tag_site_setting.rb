# frozen_string_literal: true

class DropShowFilterByTagSiteSetting < ActiveRecord::Migration[6.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'show_filter_by_tag'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
