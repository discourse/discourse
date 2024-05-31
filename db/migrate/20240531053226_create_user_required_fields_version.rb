# frozen_string_literal: true

class CreateUserRequiredFieldsVersion < ActiveRecord::Migration[7.0]
  def change
    create_table :user_required_fields_versions do |t|
      t.timestamps null: false
    end

    add_column :users, :required_fields_version, :integer
  end
end
