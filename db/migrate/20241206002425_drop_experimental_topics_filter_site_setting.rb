# frozen_string_literal: true

class DropExperimentalTopicsFilterSiteSetting < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'experimental_topics_filter'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
