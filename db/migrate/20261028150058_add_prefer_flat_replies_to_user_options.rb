# frozen_string_literal: true

class AddPreferFlatRepliesToUserOptions < ActiveRecord::Migration[8.1]
  def change
    add_column :user_options, :prefer_flat_replies, :boolean, default: false, null: false
  end
end
