# frozen_string_literal: true

class RebakeChecklistPosts < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE posts SET baked_version = NULL
      WHERE cooked LIKE '%chcklst-box%'
        AND cooked NOT LIKE '%data-chk-off%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
