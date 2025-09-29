# frozen_string_literal: true
class AddIndexToPostsLocale < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def up
    remove_index :posts, :locale, algorithm: :concurrently, if_exists: true
    add_index :posts, :locale, algorithm: :concurrently
  end

  def down
    remove_index :posts, :locale, algorithm: :concurrently, if_exists: true
  end
end
