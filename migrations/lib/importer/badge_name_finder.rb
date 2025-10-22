# frozen_string_literal: true

module Migrations::Importer
  class BadgeNameFinder < UniqueNameFinderBase
    MIN_LENGTH = 1
    MAX_LENGTH = 100

    def initialize(shared_data, min_length: nil, max_length: nil, max_attempts: nil)
      super(shared_data, min_length: MIN_LENGTH, max_length: MAX_LENGTH)
    end

    private

    def load_from_shared_data(shared_data)
      @used_badge_names_lower = shared_data.load_set <<~SQL
        SELECT LOWER(name)
        FROM badges
      SQL
    end

    def store_used_name(name_lower)
      @used_badge_names_lower.add(name_lower)
    end
  end
end
