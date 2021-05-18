# frozen_string_literal: true

class AddRejectReasonToReviewables < ActiveRecord::Migration[6.0]
  def change
    add_column :reviewables, :reject_reason, :text
  end
end
