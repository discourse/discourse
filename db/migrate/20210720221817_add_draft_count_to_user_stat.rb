# frozen_string_literal: true

class AddDraftCountToUserStat < ActiveRecord::Migration[6.1]
  def change
    add_column :user_stats, :draft_count, :integer, default: 0, null: false
  end
end
