# frozen_string_literal: true

class RemoveSuppressFromLatestFromCategory < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    categories: %i{suppress_from_latest}
  }

  def up
    muted_category_ids = SiteSetting.default_categories_muted.split("|")
    suppressed_category_ids = Category.where(suppress_from_latest: true).pluck(:id).map(&:to_s)
    SiteSetting.default_categories_muted = (muted_category_ids + suppressed_category_ids).uniq.join("|")

    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
