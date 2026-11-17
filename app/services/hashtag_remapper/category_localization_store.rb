# frozen_string_literal: true

class HashtagRemapper
  class CategoryLocalizationStore < Store
    def self.key = "category_localization"
    def self.relation = CategoryLocalization.all
    def self.raw_column = :description
  end
end
