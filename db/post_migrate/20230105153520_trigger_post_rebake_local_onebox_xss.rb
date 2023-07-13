# frozen_string_literal: true

class TriggerPostRebakeLocalOneboxXss < ActiveRecord::Migration[7.0]
  def up
    val =
      DB.query_single(
        "SELECT value FROM site_settings WHERE name = 'content_security_policy'",
      ).first

    return if val == nil || val == "t"

    DB.exec(<<~SQL)
      UPDATE posts
      SET baked_version = NULL
      WHERE cooked LIKE '%<a href=%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
