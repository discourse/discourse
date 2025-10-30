# frozen_string_literal: true

module Migrations::Importer
  class UniqueNameFinderBase
    DEFAULT_MIN_LENGTH = 3
    DEFAULT_MAX_LENGTH = 60
    DEFAULT_MAX_ATTEMPTS = 500
    TRUNCATION_CACHE_SIZE = 500

    def initialize(shared_data, min_length: nil, max_length: nil, max_attempts: nil)
      @min_length = min_length || DEFAULT_MIN_LENGTH
      @max_length = max_length || DEFAULT_MAX_LENGTH
      @max_attempts = max_attempts || DEFAULT_MAX_ATTEMPTS

      init_caches
      load_from_shared_data(shared_data)
      extract_max_suffixes_from_existing_names
    end

    def find_available_name(name)
      name, name_lower = resolve_unique_name(name)
      store_used_name(name_lower)
      name
    end

    private

    # Override in subclasses
    def load_from_shared_data(shared_data)
      nil
    end

    # Override in subclasses
    def store_used_name(name_lower)
      raise NotImplementedError
    end

    # Override in subclasses
    def existing_name_collections
      []
    end

    # Override in subclasses
    def fallback_name
      raise NotImplementedError
    end

    # Override in subclasses
    def sanitize_name(name)
      raise NotImplementedError
    end

    # Override in subclasses
    def name_available?(name_lower)
      raise NotImplementedError
    end

    # Override in subclasses
    def should_skip_suffix_attempts?(name_lower)
      false
    end

    def resolve_unique_name(original_name)
      name = sanitize_name(original_name)

      result =
        if name.present?
          name = truncate(name, max_length: @max_length)
          name_lower = name.downcase

          if name.length >= @min_length && name_available?(name_lower)
            [name, name_lower]
          elsif !should_skip_suffix_attempts?(name_lower)
            find_name_with_suffix(name, name_lower)
          end
        end

      result || find_fallback_name
    end

    def find_name_with_suffix(name, name_lower)
      original_name_lower = name_lower

      if (truncation_length = @truncations[original_name_lower])
        name = truncate(name, max_length: truncation_length)
        name_lower = name.downcase
      end

      name_length = name.length
      suffix = next_suffix(name_lower)
      suffix_str = format_suffix(name_length, suffix)
      name_candidate_lower = +"#{name_lower}#{suffix_str}"

      attempts = 0

      while attempts < @max_attempts
        if (overflow = name_candidate_lower.length - @max_length) > 0
          name = truncate(name, max_length: name.length - overflow)
          name_length = name.length
          break if name_length == 0

          name_lower = name.downcase
          @truncations[original_name_lower] = name_length

          return nil if should_skip_suffix_attempts?(name_lower)

          suffix = next_suffix(name_lower)
          suffix_str = format_suffix(name_length, suffix)
          name_candidate_lower = "#{name_lower}#{suffix_str}"
        end

        if name_available?(name_candidate_lower)
          @last_suffixes[name_lower] = suffix
          return "#{name}#{suffix_str}", name_candidate_lower
        else
          name_candidate_lower.next!
          suffix += 1
          suffix_str = format_suffix(name_length, suffix)
          name_candidate_lower = "#{name_lower}#{suffix_str}"
        end

        attempts += 1
      end

      nil
    end

    def format_suffix(base_length, suffix)
      suffix_str = "_#{suffix}"
      total_length = base_length + suffix_str.length

      if total_length < @min_length
        # Pad with leading zeros: "_01", "_001", etc.
        padding_needed = @min_length - base_length - 1
        "_#{suffix.to_s.rjust(padding_needed, "0")}"
      else
        suffix_str
      end
    end

    def find_fallback_name
      name = (@fallback_name ||= fallback_name)
      name_lower = name.downcase
      suffix = next_suffix(name_lower)
      attempts = 0

      while attempts < @max_attempts
        name_candidate = "#{name}_#{suffix}"
        name_candidate_lower = name_candidate.downcase

        if name_available?(name_candidate_lower)
          @last_suffixes[name_lower] = suffix
          return name_candidate, name_candidate_lower
        end

        suffix += 1
        attempts += 1
      end

      raise "Unable to find an available name after #{@max_attempts} attempts"
    end

    def next_suffix(name_lower)
      @last_suffixes.fetch(name_lower, 0) + 1
    end

    def truncate(name, max_length:)
      return name if name.length <= max_length

      result = +""
      name.each_grapheme_cluster do |cluster|
        break if result.length + cluster.length > max_length
        result << cluster
      end

      modify_truncated_name(result)
    end

    def modify_truncated_name(name)
      name
    end

    def init_caches
      @last_suffixes = {}
      @truncations = ::LruRedux::Cache.new(TRUNCATION_CACHE_SIZE)
    end

    def extract_max_suffixes_from_existing_names
      finder = SuffixFinder.new
      @last_suffixes = finder.find_max_suffixes(*existing_name_collections)
    end
  end
end
