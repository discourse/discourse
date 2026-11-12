# frozen_string_literal: true

class RebakeChatOneboxPosts < ActiveRecord::Migration[8.0]
  def up
    execute <<~SQL
      UPDATE posts
         SET baked_version = 0
       WHERE cooked LIKE '%chat-onebox%'
    SQL
  end

  def down
  end
end
