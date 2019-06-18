# frozen_string_literal: true

class AddSummarizedAtColumnToIgnoredUsersTable < ActiveRecord::Migration[5.2]
  def change
    add_column :ignored_users, :summarized_at, :datetime
  end
end
