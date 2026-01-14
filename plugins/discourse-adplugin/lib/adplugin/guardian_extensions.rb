# frozen_string_literal: true

module AdPlugin
  module GuardianExtensions
    def show_dfp_ads?
      !self.user.in_any_groups?(SiteSetting.dfp_exclude_groups_map)
    end

    def show_adsense_ads?
      !self.user.in_any_groups?(SiteSetting.adsense_exclude_groups_map)
    end

    def show_carbon_ads?
      !self.user.in_any_groups?(SiteSetting.carbonads_exclude_groups_map)
    end

    def show_amazon_ads?
      !self.user.in_any_groups?(SiteSetting.amazon_exclude_groups_map)
    end

    def show_adbutler_ads?
      !self.user.in_any_groups?(SiteSetting.adbutler_exclude_groups_map)
    end

    def show_to_groups?
      !self.user.in_any_groups?(SiteSetting.no_ads_for_groups_map)
    end
  end
end
