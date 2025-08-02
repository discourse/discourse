# frozen_string_literal: true

class CreateGroupDefaultTracking < ActiveRecord::Migration[6.0]
  def change
    create_table :group_category_notification_defaults do |t|
      t.integer :group_id, null: false
      t.integer :category_id, null: false
      t.integer :notification_level, null: false
    end

    add_index :group_category_notification_defaults,
              %i[group_id category_id],
              unique: true,
              name: :idx_group_category_notification_defaults_unique

    create_table :group_tag_notification_defaults do |t|
      t.integer :group_id, null: false
      t.integer :tag_id, null: false
      t.integer :notification_level, null: false
    end

    add_index :group_tag_notification_defaults,
              %i[group_id tag_id],
              unique: true,
              name: :idx_group_tag_notification_defaults_unique
  end
end
