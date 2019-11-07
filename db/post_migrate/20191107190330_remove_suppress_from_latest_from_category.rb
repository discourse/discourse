class RemoveSuppressFromLatestFromCategory < ActiveRecord::Migration[6.0]
  DROPPED_COLUMNS ||= {
    categories: %i{suppress_from_latest}
  }

  def up
    SiteSetting.default_categories_muted = Category.where(suppress_from_latest: true).pluck(:id).join("|")

    DROPPED_COLUMNS.each do |table, columns|
      Migration::ColumnDropper.execute_drop(table, columns)
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
