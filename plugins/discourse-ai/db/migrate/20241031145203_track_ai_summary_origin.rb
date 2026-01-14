# frozen_string_literal: true
class TrackAiSummaryOrigin < ActiveRecord::Migration[7.1]
  def change
    add_column :ai_summaries, :origin, :integer
  end
end
