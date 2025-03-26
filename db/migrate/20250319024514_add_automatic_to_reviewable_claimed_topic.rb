# frozen_string_literal: true
class AddAutomaticToReviewableClaimedTopic < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewable_claimed_topics, :automatic, :boolean, default: false, null: false
  end
end
