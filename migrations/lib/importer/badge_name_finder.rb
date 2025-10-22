# frozen_string_literal: true

module Migrations::Importer
  class BadgeNameFinder < UniqueNameFinderBase
    private

    def load_used_names(shared_data)
      shared_data&.load(:badge_names) || Set.new
    end

    def max_length
      ::Badge::MAX_NAME_LENGTH
    end

    def fallback_name
      "badge"
    end

    def sanitize_name(name)
      name.to_s.strip
    end
  end
end
