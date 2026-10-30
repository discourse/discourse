# frozen_string_literal: true

module AdPlugin
  class DfpCategorySetting < ActiveRecord::Base
    include AnonCacheInvalidator

    self.table_name = "ad_plugin_dfp_category_settings"

    belongs_to :category

    validates :category_id, uniqueness: true
    validates :gam_adunit, :gam_keywords, :gtm_taxonomy, length: { maximum: 255 }

    def self.site_settings_for(scope)
      where(category_id: Category.secured(scope).select(:id)).to_h do |setting|
        [
          setting.category_id.to_s,
          {
            gam_adunit: setting.gam_adunit,
            gam_keywords: setting.gam_keywords,
            gtm_taxonomy: setting.gtm_taxonomy,
          },
        ]
      end
    end

    def self.secure_settings_exist?
      joins(:category).where(categories: { read_restricted: true }).exists?
    end

    def self.publish_site_settings
      payload = { public: site_settings_for(nil), secure: secure_settings_exist? }

      MessageBus.publish("/site/dfp-category-settings/changed", payload)
    end
  end
end

# == Schema Information
#
# Table name: ad_plugin_dfp_category_settings
#
#  id           :bigint           not null, primary key
#  gam_adunit   :string
#  gam_keywords :string
#  gtm_taxonomy :string
#  created_at   :datetime         not null
#  updated_at   :datetime         not null
#  category_id  :integer          not null
#
# Indexes
#
#  index_ad_plugin_dfp_category_settings_on_category_id  (category_id) UNIQUE
#
