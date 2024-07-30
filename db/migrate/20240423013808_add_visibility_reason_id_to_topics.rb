# frozen_string_literal: true

class AddVisibilityReasonIdToTopics < ActiveRecord::Migration[7.0]
  def change
    add_column :topics, :visibility_reason_id, :integer
  end
end
