# frozen_string_literal: true

class AddsDiscourseAutomationUserGlobalNotice < ActiveRecord::Migration[6.1]
  def change
    create_table :discourse_automation_user_global_notices do |t|
      t.integer :user_id, null: false
      t.text :notice, null: false
      t.string :identifier, null: false
      t.string :level, default: "info"
      t.timestamps null: false
    end

    add_index :discourse_automation_user_global_notices,
              %i[user_id identifier],
              unique: true,
              name: :idx_discourse_automation_user_global_notices
  end
end
