# frozen_string_literal: true

class RemoveEnableExperimentalHashtagAutocompleteSetting < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      DELETE FROM site_settings
      WHERE name = 'enable_experimental_hashtag_autocomplete'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
