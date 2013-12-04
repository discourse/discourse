class RenameBestOfToSummary < ActiveRecord::Migration
  def change
    rename_column :topics, :has_best_of, :has_summary
  end
end
