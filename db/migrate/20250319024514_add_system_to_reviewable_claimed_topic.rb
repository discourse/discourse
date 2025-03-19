# frozen_string_literal: true
class AddSystemToReviewableClaimedTopic < ActiveRecord::Migration[7.2]
  def change
    add_column :reviewable_claimed_topics, :system, :boolean, default: false, null: false
  end
end
