# frozen_string_literal: true

module AdPlugin
  class HouseAdRoute < ActiveRecord::Base
    self.table_name = "ad_plugin_house_ads_routes"

    belongs_to :house_ad, class_name: "AdPlugin::HouseAd", foreign_key: "ad_plugin_house_ad_id"

    validates :route_name, presence: true
  end
end
