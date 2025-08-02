# frozen_string_literal: true

class EnableExperimentalHashtagAutocompleteTrueForAllSites < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE site_settings
      SET value = 't'
      WHERE name = 'enable_experimental_hashtag_autocomplete'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
