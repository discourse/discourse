# frozen_string_literal: true

class HashtagRemapper
  class TagDescriptionStore < Store
    def self.key = "tag_description"
    def self.relation = Tag.all
    def self.raw_column = :description
    def self.cooked(tag) = tag.description_cooked
    def self.cook_options(tag) = HasCookedTagDescription::COOK_OPTIONS
  end
end
