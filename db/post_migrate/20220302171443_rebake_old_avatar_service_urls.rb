# frozen_string_literal: true

class RebakeOldAvatarServiceUrls < ActiveRecord::Migration[6.1]
  def up
    execute <<~SQL
      UPDATE posts SET baked_version = 0
      WHERE cooked LIKE '%avatars.discourse.org%'
    SQL
  end

  def down
    # Nothing to do
  end
end
