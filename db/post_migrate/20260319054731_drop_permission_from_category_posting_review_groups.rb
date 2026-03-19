# frozen_string_literal: true

require "migration/column_dropper"

class DropPermissionFromCategoryPostingReviewGroups < ActiveRecord::Migration[8.0]
  DROPPED_COLUMNS = { category_posting_review_groups: %i[permission] }

  def up
    DROPPED_COLUMNS.each { |table, columns| Migration::ColumnDropper.execute_drop(table, columns) }
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
