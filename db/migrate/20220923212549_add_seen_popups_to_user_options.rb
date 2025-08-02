# frozen_string_literal: true

class AddSeenPopupsToUserOptions < ActiveRecord::Migration[7.0]
  def change
    add_column :user_options, :seen_popups, :integer, array: true
  end
end
