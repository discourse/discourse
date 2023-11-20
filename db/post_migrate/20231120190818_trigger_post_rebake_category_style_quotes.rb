# frozen_string_literal: true

class TriggerPostRebakeCategoryStyleQuotes < ActiveRecord::Migration[7.0]
  def up
    DB.exec(<<~SQL)
      UPDATE posts
      SET baked_version = NULL
      WHERE cooked LIKE '%blockquote%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
