# frozen_string_literal: true

module Migrations::Importer
  class BadgeNameFinder < UniqueNameFinderBase
    def initialize(shared_data, min_length: nil, max_length: nil, max_attempts: nil)
      super(shared_data, min_length: 1, max_length: 100)
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

    def existing_name_collections
      [@used_badge_names_lower]
    end

    def fallback_name
      I18n.t("importer.fallback_names.badge")
    end

    def sanitize_name(name)
      name.scrub.strip if name.present?
    end

    def name_available?(name_lower)
      !@used_badge_names_lower.include?(name_lower)
    end
  end
end
