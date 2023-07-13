# frozen_string_literal: true

class AddCreatedByIndexToReviewables < ActiveRecord::Migration[5.2]
  def change
    add_index :reviewables, %i[topic_id status created_by_id]
  end
end
