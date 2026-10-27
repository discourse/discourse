# frozen_string_literal: true
class AddPeriodSolutionsIndexToDirectoryItems < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    remove_index :directory_items,
                 %i[period_type solutions id],
                 algorithm: :concurrently,
                 if_exists: true
    add_index :directory_items, %i[period_type solutions id], algorithm: :concurrently
  end

  def down
    remove_index :directory_items,
                 %i[period_type solutions id],
                 algorithm: :concurrently,
                 if_exists: true
  end
end
