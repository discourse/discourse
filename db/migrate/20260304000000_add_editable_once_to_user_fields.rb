# frozen_string_literal: true

class AddEditableOnceToUserFields < ActiveRecord::Migration[8.0]
  def change
    add_column :user_fields, :editable_once, :boolean, default: false, null: false
  end
end
