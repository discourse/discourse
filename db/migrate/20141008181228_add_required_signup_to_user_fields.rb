# frozen_string_literal: true

class AddRequiredSignupToUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :user_fields, :required, :boolean, default: true, null: false
  end
end
