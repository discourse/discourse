# frozen_string_literal: true

class CreateHouseAdsRoutesTable < ActiveRecord::Migration[7.0]
  def change
    create_table :ad_plugin_house_ads_routes, id: false do |t|
      t.bigint :ad_plugin_house_ad_id, null: false
      t.string :route_name, null: false
    end

    add_foreign_key :ad_plugin_house_ads_routes,
                    :ad_plugin_house_ads,
                    column: :ad_plugin_house_ad_id

    add_index :ad_plugin_house_ads_routes,
              %i[ad_plugin_house_ad_id route_name],
              unique: true,
              name: "index_house_ads_pages"
  end
end
