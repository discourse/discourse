# frozen_string_literal: true
class RebakePostsWithHeadingAnchors < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE posts SET baked_version = NULL
      WHERE cooked LIKE '%class="anchor"%'
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
