# frozen_string_literal: true

class RenameBestOfToSummary < ActiveRecord::Migration[4.2]
  def change
    rename_column :topics, :has_best_of, :has_summary
  end
end
