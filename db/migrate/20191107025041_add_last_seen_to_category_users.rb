# frozen_string_literal: true

class AddLastSeenToCategoryUsers < ActiveRecord::Migration[6.0]
  def change
    add_column :category_users, :last_seen_at, :datetime
  end
end
