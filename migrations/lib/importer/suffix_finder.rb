# frozen_string_literal: true

module Migrations::Importer
  class SuffixFinder
    def find(names_lower)
      suffixes_by_base = extract_suffixes(names_lower)
      suffixes_by_base.transform_values! do |suffixes|
        suffixes.sort!

        ranges = []
        current_range = [suffixes[0]]

        suffixes.each_cons(2) do |a, b|
          if b - a < 100
            current_range << b
          else
            ranges << current_range
            current_range = [b]
          end
        end
        ranges << current_range # Don't forget the last range

        # Filter: keep first range always, others only if size >= 300
        filtered_ranges = ranges.select.with_index { |range, idx| idx == 0 || range.size >= 300 }

        # Return the end (max) of the last range
        filtered_ranges.last.max
      end
    end

    private

    # Extracts numeric suffixes from names following the pattern "base_123"
    # @param names_lower [Enumerable<String>] list of lower-case names to analyze
    # @return [Hash<String, Array<Integer>>] base names mapped to their suffixes
    def extract_suffixes(names_lower)
      suffixes_by_base = Hash.new { |h, k| h[k] = [] }

      names_lower.each do |name|
        base_name, suffix = name.match(/\A(.+?)_(\d+)\z/)&.captures
        suffixes_by_base[base_name] << suffix.to_i if base_name
      end

      suffixes_by_base
    end
  end
end
