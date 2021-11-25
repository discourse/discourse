# frozen_string_literal: true

class AddRecentSearches < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :oldest_search_log_date, :datetime

    add_index :search_logs, [:user_id, :created_at], where: 'user_id IS NOT NULL'
  end
end
