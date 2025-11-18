# frozen_string_literal: true
class AddBundleToReviewableActionLogs < ActiveRecord::Migration[8.0]
  def change
    add_column :reviewable_action_logs, :bundle, :string, null: false
    add_index :reviewable_action_logs, :bundle
  end
end
