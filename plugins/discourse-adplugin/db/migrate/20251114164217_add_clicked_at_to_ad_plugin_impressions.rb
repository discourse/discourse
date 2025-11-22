# frozen_string_literal: true

class AddClickedAtToAdPluginImpressions < ActiveRecord::Migration[7.0]
  def change
    add_column :ad_plugin_impressions, :clicked_at, :datetime
    add_index :ad_plugin_impressions, :clicked_at
  end
end
