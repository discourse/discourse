# frozen_string_literal: true

class AddSiteSettingGroups < ActiveRecord::Migration[8.0]
  def change
    create_table :site_setting_groups do |t|
      t.string :name, null: false
      t.string :group_ids, null: false
      t.timestamps
    end

    add_index :site_setting_groups, :name, unique: true
  end
end
