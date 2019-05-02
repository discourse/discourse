# frozen_string_literal: true

class AddDigestAfterDaysToUsers < ActiveRecord::Migration[4.2]
  def change
    add_column :users, :digest_after_days, :integer, default: 7, null: false
  end
end
