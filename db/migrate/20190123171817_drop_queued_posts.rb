# frozen_string_literal: true

class DropQueuedPosts < ActiveRecord::Migration[5.2]
  def up
    drop_table :queued_posts
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
