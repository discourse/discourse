# frozen_string_literal: true

module AdPlugin
  class AdImpression < ActiveRecord::Base
    self.table_name = "ad_plugin_impressions"

    belongs_to :house_ad,
               class_name: "AdPlugin::HouseAd",
               foreign_key: "ad_plugin_house_ad_id",
               optional: true

    belongs_to :user, optional: true

    enum :ad_type, AdType.enum_hash

    validates :ad_type, presence: true
    validates :placement, presence: true

    validates :ad_plugin_house_ad_id, presence: true, if: :house?

    validate :house_ad_id_consistency

    def record_click!
      return false if clicked?

      update(clicked_at: Time.zone.now)
    end

    def clicked?
      clicked_at.present?
    end

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
#  id                    :bigint           not null, primary key
#  ad_type               :integer          not null
#  placement             :string           not null
#  created_at            :datetime         not null
#  updated_at            :datetime         not null
#  ad_plugin_house_ad_id :bigint
#  user_id               :integer
#  clicked_at            :datetime
#
# Indexes
#
#  index_ad_plugin_impressions_on_ad_plugin_house_ad_id  (ad_plugin_house_ad_id)
#  index_ad_plugin_impressions_on_ad_type                (ad_type)
#  index_ad_plugin_impressions_on_ad_type_and_placement  (ad_type,placement)
#  index_ad_plugin_impressions_on_clicked_at             (clicked_at)
#  index_ad_plugin_impressions_on_created_at             (created_at)
#  index_ad_plugin_impressions_on_user_id                (user_id)
#
# Foreign Keys
#
#  fk_rails_...  (ad_plugin_house_ad_id => ad_plugin_house_ads.id) ON DELETE => cascade
#  fk_rails_...  (user_id => users.id) ON DELETE => nullify
#
