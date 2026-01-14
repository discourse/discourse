# frozen_string_literal: true
class AddAiSummaryTypeColumn < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_summaries, :summary_type, :integer, default: 0, null: false
  end
end
