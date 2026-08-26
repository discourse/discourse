# frozen_string_literal: true

class HashtagRemapper
  class GroupStore < Store
    def self.key = "group"
    def self.relation = Group.all
    def self.raw_column = :bio_raw
    def self.cooked(group) = group.bio_cooked
  end
end
