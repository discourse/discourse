# frozen_string_literal: true

class AddShowOnSignupToUserFields < ActiveRecord::Migration[8.0]
  def change
    add_column :user_fields, :show_on_signup, :boolean, null: false, default: true
  end
end
