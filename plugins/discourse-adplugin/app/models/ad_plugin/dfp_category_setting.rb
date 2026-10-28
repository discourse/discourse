# frozen_string_literal: true

module AdPlugin
  class DfpCategorySetting < ActiveRecord::Base
    include AnonCacheInvalidator

    self.table_name = "ad_plugin_dfp_category_settings"

    belongs_to :category

    validates :category_id, uniqueness: true
    validates :gam_adunit, :gam_keywords, :gtm_taxonomy, length: { maximum: 255 }

    # Per-category GAM map keyed by category id, restricted to categories the
    # given scope can see. Shared by the :site serializer and the authenticated
    # live-update refetch so the category editor and runtime ad targeting read one
    # source.
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

    # Broadcast the public map (safe for every subscriber) plus a flag. Anonymous
    # viewers get their complete answer from the public map alone and fetch
    # nothing; every logged-in client re-fetches its own map over an authenticated
    # request when private config exists, because the public map is only a subset
    # of what members of secure categories are allowed to see.
    def self.publish_site_settings
      payload = { public: site_settings_for(nil), secure: secure_settings_exist? }

      MessageBus.publish("/site/dfp-category-settings/changed", payload)
    end
  end
end
