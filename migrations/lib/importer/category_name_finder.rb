# frozen_string_literal: true

module Migrations::Importer
  class CategoryNameFinder < UniqueNameFinderBase
    protected

    def load_used_names(shared_data)
      shared_data&.load(:category_names) || Set.new
    end

    def max_length
      ::Category::MAX_NAME_LENGTH
    end

    def fallback_name
      "category"
    end

    def sanitize_name(name)
      name.to_s.strip
    end
  end
end
