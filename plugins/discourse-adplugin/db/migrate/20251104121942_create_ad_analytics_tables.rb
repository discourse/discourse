# frozen_string_literal: true

class CreateAdAnalyticsTables < ActiveRecord::Migration[7.0]
  def change
    create_table :ad_plugin_impressions do |t|
      t.integer :ad_type, null: false
      t.bigint :ad_plugin_house_ad_id
      t.string :placement, null: false
      t.integer :user_id
      t.timestamps
    end

    add_index :ad_plugin_impressions, :ad_type
    add_index :ad_plugin_impressions, :ad_plugin_house_ad_id
    add_index :ad_plugin_impressions, :user_id
    add_index :ad_plugin_impressions, %i[ad_type placement]
    add_index :ad_plugin_impressions, :created_at

    add_foreign_key :ad_plugin_impressions,
                    :ad_plugin_house_ads,
                    column: :ad_plugin_house_ad_id,
                    on_delete: :cascade
    add_foreign_key :ad_plugin_impressions, :users, column: :user_id, on_delete: :nullify
  end
end
