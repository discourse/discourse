# frozen_string_literal: true

module Migrations::Importer
  # Finds the highest numeric suffix for each base name that belongs to a sufficiently large,
  # contiguous range of suffixes.
  #
  # This class analyzes names with numeric suffixes (e.g., "user_1", "user_2", "user_3")
  # and identifies ranges of consecutive suffixes, preferring the range with the highest
  # suffix that meets the size threshold.
  #
  # @example
  #   finder = SuffixFinder.new
  #   names = ["user_1", "user_2", "user_3", "user_100", "user_101"]
  #   finder.find_max_suffixes(names)
  #   # => { "user" => 3 }
  #   # Returns 3 because [1..3] is the first range from the end that could qualify
  #
  # @example With large range
  #   names = (1..50).map { |i| "user_#{i}" } + (1..400).map { |i| "user_#{i}" }
  #   finder.find_max_suffixes(names)
  #   # => { "user" => 400 }
  #   # Returns 400 because the range [1..400] has 400 elements (>= 300 threshold)
  class SuffixFinder
    # Default maximum gap between consecutive suffixes before starting a new range
    DEFAULT_MAX_GAP = 100

    # Default minimum range size to qualify as a "large" range
    DEFAULT_LARGE_RANGE_THRESHOLD = 300

    private_constant :DEFAULT_MAX_GAP, :DEFAULT_LARGE_RANGE_THRESHOLD

    # @param max_gap [Integer] maximum gap between consecutive suffixes (default: 100)
    # @param large_range_threshold [Integer] minimum range size to qualify (default: 300)
    def initialize(max_gap: DEFAULT_MAX_GAP, large_range_threshold: DEFAULT_LARGE_RANGE_THRESHOLD)
      @max_gap = max_gap
      @large_range_threshold = large_range_threshold
    end

    # Finds the highest suffix for each base name that belongs to a qualifying range.
    #
    # Ranges are split when gaps between consecutive suffixes are >= max_gap.
    # The method iterates ranges in reverse (from highest to lowest suffix) and returns
    # the maximum suffix from the first range that is >= large_range_threshold in size.
    # If no range meets the threshold, returns the maximum suffix from the first range.
    #
    # @param names_lower_collections [Array<Enumerable<String>>] one or more collections of lowercase names with numeric suffixes
    # @return [Hash<String, Integer>] mapping of base names to their selected maximum suffix
    #
    # @example Multiple ranges with gap
    #   find_max_suffixes(["user_1", "user_2", "user_200", "user_201"])
    #   # => { "user" => 2 }
    #   # Gap of 197 splits into ranges [1..2] and [200..201], returns first range's max
    #
    # @example Large qualifying range
    #   names = (1..400).map { |i| "user_#{i}" }
    #   find_max_suffixes(names)
    #   # => { "user" => 400 }
    #
    # @example Multiple collections
    #   find_max_suffixes(["user_1", "user_2"], ["user_3", "user_100"])
    #   # => { "user" => 3 }
    def find_max_suffixes(*names_lower_collections)
      suffixes_by_base = extract_suffixes(names_lower_collections)

      suffixes_by_base.transform_values! do |suffixes|
        next if suffixes.empty?

        suffixes.sort!

        range_end = suffixes.last

        suffixes
          .reverse_each
          .each_cons(2) do |current_suffix, previous_suffix|
            range_size = range_end - current_suffix

            if range_size >= @large_range_threshold
              break range_end
            elsif current_suffix - previous_suffix >= @max_gap
              range_end = previous_suffix
            end
          end

        range_end
      end
    end

    private

    # Extracts numeric suffixes from names following the pattern "base_123"
    # @param names_lower_collections [Array<Enumerable<String>>] one or more collections of lowercase names to analyze
    # @return [Hash<String, Array<Integer>>] base names mapped to their suffixes
    def extract_suffixes(names_lower_collections)
      suffixes_by_base = Hash.new { |h, k| h[k] = [] }

      names_lower_collections.each do |names_lower|
        names_lower.each do |name|
          base_name, suffix = name.match(/\A(.+?)_(\d+)\z/)&.captures
          suffixes_by_base[base_name] << suffix.to_i if base_name
        end
      end

      suffixes_by_base
    end
  end
end
