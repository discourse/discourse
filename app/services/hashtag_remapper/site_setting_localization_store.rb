# frozen_string_literal: true

class HashtagRemapper
  class SiteSettingLocalizationStore < Store
    def self.key = "site_setting_localization"
    def self.relation = SiteSettingLocalization.where.not(cooked: nil)
    def self.raw_column = :value
    def self.cooked(localization) = localization.cooked

    def self.write!(localization, raw)
      localization.value = raw
      localization.save!
    end
  end
end
