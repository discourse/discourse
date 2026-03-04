# frozen_string_literal: true

module AdPlugin
  class HouseAdRoute < ActiveRecord::Base
    self.table_name = "ad_plugin_house_ads_routes"

    belongs_to :house_ad, class_name: "AdPlugin::HouseAd", foreign_key: "ad_plugin_house_ad_id"

    validates :route_name, presence: true
  end
end

# == Schema Information
#
# Table name: ad_plugin_house_ads_routes
#
#  route_name            :string           not null
#  ad_plugin_house_ad_id :bigint           not null
#
# Indexes
#
#  index_house_ads_pages  (ad_plugin_house_ad_id,route_name) UNIQUE
#
# Foreign Keys
#
#  fk_rails_...  (ad_plugin_house_ad_id => ad_plugin_house_ads.id)
#
