# frozen_string_literal: true

class CreateSiteSettingLocalizations < ActiveRecord::Migration[8.0]
  def change
    create_table :site_setting_localizations do |t|
      t.string :setting_name, null: false
      t.string :locale, null: false, limit: 20
      t.text :value, null: false
      t.text :cooked
      t.integer :localizer_user_id

      t.timestamps null: false
    end

    add_index :site_setting_localizations, :locale
    add_index :site_setting_localizations, %i[setting_name locale], unique: true
  end
end
