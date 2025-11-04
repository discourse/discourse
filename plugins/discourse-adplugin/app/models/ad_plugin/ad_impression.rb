# frozen_string_literal: true

module AdPlugin
  class AdImpression < ActiveRecord::Base
    self.table_name = "ad_plugin_impressions"

    belongs_to :house_ad,
               class_name: "AdPlugin::HouseAd",
               foreign_key: "ad_plugin_house_ad_id",
               optional: true

    belongs_to :user, optional: true

    # has_many :clicks,
    #          class_name: "AdPlugin::AdClick",
    #          foreign_key: "ad_plugin_impression_id",
    #          dependent: :destroy

    enum ad_type: { house: 0, adsense: 1, dfp: 2, amazon: 3, carbon: 4, adbutler: 5 }

    validates :ad_type, presence: true
    validates :placement, presence: true

    validates :ad_plugin_house_ad_id, presence: true, if: :house?
    validates :ad_network_name, presence: true, unless: :house?

    validate :house_ad_id_consistency

    scope :recent, -> { order(created_at: :desc) }
    scope :for_placement, ->(placement) { where(placement: placement) }
    scope :for_user, ->(user_id) { where(user_id: user_id) }
    scope :house_ads, -> { where(ad_type: :house) }
    scope :external_ads, -> { where.not(ad_type: :house) }

    private

    def house_ad_id_consistency
      if house? && ad_plugin_house_ad_id.nil?
        errors.add(:ad_plugin_house_ad_id, "must be present for house ads")
      elsif !house? && ad_plugin_house_ad_id.present?
        errors.add(:ad_plugin_house_ad_id, "must be nil for external ads")
      end
    end
  end
end

# == Schema Information
#
# Table name: ad_plugin_impressions
#
#  id                      :bigint           not null, primary key
#  ad_type                 :integer          not null
#  ad_plugin_house_ad_id   :bigint
#  ad_network_name         :string
#  placement               :string           not null
#  user_id                 :integer
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#
