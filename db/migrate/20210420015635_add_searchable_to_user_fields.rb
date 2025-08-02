# frozen_string_literal: true

class AddSearchableToUserFields < ActiveRecord::Migration[6.0]
  def change
    add_column :user_fields, :searchable, :boolean, default: false, null: false
  end
end
