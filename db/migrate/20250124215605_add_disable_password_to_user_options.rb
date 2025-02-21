# frozen_string_literal: true
class AddDisablePasswordToUserOptions < ActiveRecord::Migration[7.2]
  def change
    add_column :user_options, :password_disabled, :boolean, default: false, null: false
  end
end
