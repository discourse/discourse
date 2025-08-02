# frozen_string_literal: true
class CreateAdminNotices < ActiveRecord::Migration[7.0]
  def change
    create_table :admin_notices do |t|
      t.integer :subject, null: false, index: true
      t.integer :priority, null: false

      t.string :identifier, null: false, index: true
      t.json :details, null: false, default: {}

      t.timestamps
    end
  end
end
