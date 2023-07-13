# frozen_string_literal: true

class MakeExperimentalHashtagFeatureDefaultForNewSites < ActiveRecord::Migration[7.0]
  def up
    settings_insert_query = <<~SQL
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('enable_experimental_hashtag_autocomplete', 5, 'f', now(), now())
      ON CONFLICT DO NOTHING
    SQL

    # keep enable_experimental_hashtag_autocomplete disabled for for existing sites
    execute settings_insert_query if Migration::Helpers.existing_site?
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
