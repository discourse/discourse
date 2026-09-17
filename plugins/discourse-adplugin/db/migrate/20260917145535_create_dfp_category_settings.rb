# frozen_string_literal: true

class CreateDfpCategorySettings < ActiveRecord::Migration[8.0]
  def change
    create_table :ad_plugin_dfp_category_settings do |t|
      t.integer :category_id, null: false
      t.string :gam_adunit
      t.string :gam_keywords
      t.string :gtm_taxonomy
      t.timestamps null: false
    end

    add_index :ad_plugin_dfp_category_settings, :category_id, unique: true
  end
end
