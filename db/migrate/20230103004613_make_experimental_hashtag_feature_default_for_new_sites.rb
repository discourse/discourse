# frozen_string_literal: true

class MakeExperimentalHashtagFeatureDefaultForNewSites < ActiveRecord::Migration[7.0]
  def up
    enable_experimental_hashtag_autocomplete =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'enable_experimental_hashtag_autocomplete'",
      )[
        0
      ]

    if enable_experimental_hashtag_autocomplete == "t" ||
         enable_experimental_hashtag_autocomplete == "f"
      return
    end

    execute(<<~SQL)
      INSERT INTO site_settings (name, data_type, value, created_at, updated_at)
      VALUES ('enable_experimental_hashtag_autocomplete', 5, 'f', now(), now())
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
