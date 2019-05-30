# frozen_string_literal: true

class AddEditableToUserFields < ActiveRecord::Migration[4.2]
  def change
    add_column :user_fields, :editable, :boolean, default: false, null: false
  end
end
