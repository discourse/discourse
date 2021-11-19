# frozen_string_literal: true

class AddEnableRecentSearchesToUserOptions < ActiveRecord::Migration[6.1]
  def change
    add_column :user_options, :enable_recent_searches, :boolean, default: true, null: false
  end
end
