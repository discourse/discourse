# frozen_string_literal: true

class AddExpiresAtToUserHistories < ActiveRecord::Migration[8.1]
  def change
    add_column :user_histories, :expires_at, :datetime
  end
end
