# frozen_string_literal: true

class AddIndexCreatedAtOnSearchLogs < ActiveRecord::Migration[5.2]
  def change
    add_index :search_logs, :created_at
  end
end
