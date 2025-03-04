# frozen_string_literal: true

class AddIndexToPostStatComposerColumns < ActiveRecord::Migration[7.2]
  disable_ddl_transaction!

  def change
    add_index :post_stats, :composer_version, algorithm: :concurrently
    add_index :post_stats, :writing_device, algorithm: :concurrently
  end
end
