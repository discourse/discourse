# frozen_string_literal: true

class AddIconToUserFields < ActiveRecord::Migration[5.2]
  def change
    add_column :user_fields, :icon, :string, null: true
  end
end
