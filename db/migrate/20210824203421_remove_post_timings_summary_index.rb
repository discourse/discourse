# frozen_string_literal: true

class RemovePostTimingsSummaryIndex < ActiveRecord::Migration[6.1]
  def change
    remove_index :post_timings,
                 column: %i[topic_id post_number],
                 name: :post_timings_summary,
                 if_exists: true
  end
end
