# frozen_string_literal: true

module Migrations::Importer
  class CategoryNameFinder < UniqueNameFinderBase
    def initialize(shared_data, min_length: nil, max_length: nil, max_attempts: nil)
      super(shared_data, min_length: 1, max_length: 50)

      @last_suffixes_by_parent_id = Hash.new { |h, k| h[k] = {} }
      @truncations_by_parent_id =
        Hash.new { |h, k| h[k] = ::LruRedux::Cache.new(TRUNCATION_CACHE_SIZE) }
    end

    def find_available_name(name, parent_id)
      with_parent_scope(parent_id) { super(name) }
    end

    private

    def with_parent_scope(parent_id)
      @parent_id = parent_id
      @last_suffixes = @last_suffixes_by_parent_id[parent_id]
      @truncations = @truncations_by_parent_id[parent_id]

      yield
    ensure
      @parent_id = @last_suffixes = @truncations = nil
    end

    def load_from_shared_data(shared_data)
      @used_category_names_lower = shared_data.load_set <<~SQL
        SELECT parent_category_id, LOWER(name)
        FROM categories
      SQL
    end

    def store_used_name(name_lower)
      @used_category_names_lower.add(@parent_id, name_lower)
    end

    def init_caches
      # Parent-scoped caches initialized in constructor
    end

    def extract_max_suffixes_from_existing_names
      # Suffixes tracked per parent, no need to pre-extract
    end

    def fallback_name
      I18n.t("importer.fallback_names.category")
    end

    def sanitize_name(name)
      name.scrub.strip if name.present?
    end

    def name_available?(name_lower)
      !@used_category_names_lower.include?(@parent_id, name_lower)
    end
  end
end
