# frozen_string_literal: true

class CreateHouseAdsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :ad_plugin_house_ads do |t|
      t.string :name, null: false
      t.text :html, null: false
      t.boolean :visible_to_logged_in_users, default: true, null: false
      t.boolean :visible_to_anons, default: true, null: false
      t.timestamps
    end

    create_table :ad_plugin_house_ads_groups, id: false do |t|
      t.bigint :ad_plugin_house_ad_id, null: false
      t.bigint :group_id, null: false
    end

    create_table :ad_plugin_house_ads_categories, id: false do |t|
      t.bigint :ad_plugin_house_ad_id, null: false
      t.bigint :category_id, null: false
    end

    add_index :ad_plugin_house_ads, :name, unique: true
    add_index :ad_plugin_house_ads, :visible_to_logged_in_users
    add_index :ad_plugin_house_ads, :visible_to_anons
    add_index :ad_plugin_house_ads_groups,
              %i[ad_plugin_house_ad_id group_id],
              name: "index_house_ads_groups"
    add_index :ad_plugin_house_ads_categories,
              %i[ad_plugin_house_ad_id category_id],
              name: "index_house_ads_categories"
  end
end
