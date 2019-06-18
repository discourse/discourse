# frozen_string_literal: true

class ForceRebakeOnPostsWithImages < ActiveRecord::Migration[5.2]
  def up

    # commit message has more info:
    # Picking up changes with pngquant, placeholder image, new image magick, retina images

    execute <<~SQL
      UPDATE posts SET baked_version = 0
      WHERE id IN (SELECT post_id FROM post_uploads)
    SQL
  end

  def down
    # no op, does not really matter
  end
end
