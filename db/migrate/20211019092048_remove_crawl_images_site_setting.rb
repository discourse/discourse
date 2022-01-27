# frozen_string_literal: true

class RemoveCrawlImagesSiteSetting < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      DELETE
      FROM site_settings
      WHERE name = 'crawl_images';
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
