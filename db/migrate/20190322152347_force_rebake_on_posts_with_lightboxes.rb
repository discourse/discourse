# frozen_string_literal: true

class ForceRebakeOnPostsWithLightboxes < ActiveRecord::Migration[5.2]
  def up
    # Picking up changes to lightbox HTML in cooked_post_processor
    execute <<~SQL
      UPDATE posts SET baked_version = 0
      WHERE cooked LIKE '%lightbox-wrapper%'
    SQL
  end

  def down
    # no op, does not really matter
  end
end
