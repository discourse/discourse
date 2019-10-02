# frozen_string_literal: true

class AddSecureIdentifierColumnToUsers < ActiveRecord::Migration[5.2]
  def change
    add_column :users, :secure_identifier, :string
    add_index :users, :secure_identifier, unique: true
  end
end
