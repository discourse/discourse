# frozen_string_literal: true

module Migrations::Importer
  class SuffixFinder
    MAX_SAFE_SPAN = 500

    private_constant :MAX_SAFE_SPAN

    def find_highest_in_range(suffixes)
      return nil if suffixes.empty?

      sorted = suffixes.sort
      ranges = find_contiguous_ranges(sorted)

      # Find ranges with span > MAX_SAFE_SPAN (problematic ranges we need to account for)
      large_ranges = ranges.select { |range| range_span(range) > MAX_SAFE_SPAN }

      # If we have problematic large ranges, return the max from those
      return large_ranges.map(&:max).max unless large_ranges.empty?

      # Otherwise, all ranges are small enough to ignore, return max from first range
      ranges.first.max
    end

    private

    def range_span(range)
      range.max - range.min
    end

    def find_contiguous_ranges(sorted_suffixes)
      ranges = []
      current_range = [sorted_suffixes.first]

      sorted_suffixes.each_cons(2) do |prev, curr|
        if curr - prev <= @max_suffix_gap
          current_range << curr
        else
          ranges << current_range
          current_range = [curr]
        end
      end

      ranges << current_range
      ranges
    end
  end
end
