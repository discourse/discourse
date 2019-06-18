# frozen_string_literal: true

class AddLastSeenAtToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :last_seen_at, :datetime
  end
end
