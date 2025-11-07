# frozen_string_literal: true

Fabricator(:house_ad_impression, from: "AdPlugin::AdImpression") do
  ad_type { AdPlugin::AdType.types[:house] }
  placement { AdPlugin::HouseAdSetting::DEFAULTS.keys[0].to_s }
  house_ad
end

Fabricator(:external_ad_impression, from: "AdPlugin::AdImpression") do
  ad_type { AdPlugin::AdType.types[:amazon] }
  placement { AdPlugin::HouseAdSetting::DEFAULTS.keys[0].to_s }
end
