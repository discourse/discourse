# frozen_string_literal: true
class AddCookedToAiSummaries < ActiveRecord::Migration[8.1]
  def change
    add_column :ai_summaries, :summarized_cooked, :text
  end
end
