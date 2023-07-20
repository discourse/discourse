# frozen_string_literal: true

class RebakeLazyYtPosts < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE posts SET baked_version = 0
      WHERE cooked LIKE '%lazyYT-container%'
    SQL
  end

  def down
    # do nothing
  end
end
