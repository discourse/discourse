# frozen_string_literal: true

class AddUserAgentToSearchLogs < ActiveRecord::Migration[7.1]
  def change
    add_column :search_logs, :user_agent, :string, null: true, limit: 2000
  end
end
