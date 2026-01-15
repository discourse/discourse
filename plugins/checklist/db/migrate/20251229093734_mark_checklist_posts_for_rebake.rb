# frozen_string_literal: true

class MarkChecklistPostsForRebake < ActiveRecord::Migration[7.2]
  def up
    # Mark posts containing checkboxes for rebaking so they get the new
    # data-chk-off attribute added during cooking
    execute <<~SQL
      UPDATE posts
      SET baked_version = NULL
      WHERE baked_version IS NOT NULL
        AND deleted_at IS NULL
        AND raw ~ '\\[[ xX]\\]'
    SQL
  end

  def down
    # No-op - posts will just be rebaked with whatever version is current
  end
end
