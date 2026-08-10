# frozen_string_literal: true

class AddTargetCreatedByIndexToReviewables < ActiveRecord::Migration[8.0]
  disable_ddl_transaction!

  def change
    add_index :reviewables, :target_created_by_id, algorithm: :concurrently, if_not_exists: true
  end
end
