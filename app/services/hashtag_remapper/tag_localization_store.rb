# frozen_string_literal: true

class HashtagRemapper
  class TagLocalizationStore < Store
    def self.key = "tag_localization"
    def self.relation = TagLocalization.all
    def self.raw_column = :description
    def self.cooked(localization) = localization.description_cooked
    def self.cook_options(localization) = HasCookedTagDescription::COOK_OPTIONS
  end
end
