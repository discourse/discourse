# frozen_string_literal: true

class CreateCategorySettings < ActiveRecord::Migration[7.0]
  def change
    # Moving the custom fields in core into a dedicated table for
    # better type casting, validations, etc.
    create_table :category_settings do |t|
      t.references :category, null: false, index: { unique: true }

      t.boolean :require_topic_approval, null: true
      t.boolean :require_reply_approval, null: true
      t.integer :num_auto_bump_daily, null: true

      t.timestamps
    end
  end
end
