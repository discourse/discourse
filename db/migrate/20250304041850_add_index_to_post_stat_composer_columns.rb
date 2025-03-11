# frozen_string_literal: true

class AddIndexToPostStatComposerColumns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def up
    if !index_exists?(:post_stats, :composer_version)
      add_index :post_stats, :composer_version, algorithm: :concurrently
    end
    if !index_exists?(:post_stats, :writing_device)
      add_index :post_stats, :writing_device, algorithm: :concurrently
    end
  end

  def down
    remove_index :post_stats, :composer_version if index_exists?(:post_stats, :composer_version)
    remove_index :post_stats, :writing_device if index_exists?(:post_stats, :writing_device)
  end
end
