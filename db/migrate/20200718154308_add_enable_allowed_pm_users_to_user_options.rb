# frozen_string_literal: true

class AddEnableAllowedPmUsersToUserOptions < ActiveRecord::Migration[6.0]
  def change
    add_column :user_options, :enable_allowed_pm_users, :boolean, default: false, null: false
  end
end
