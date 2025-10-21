# frozen_string_literal: true

module Migrations::Importer
  class SuffixFinder
    MAX_GAP = 100
    LARGE_RANGE_THRESHOLD = 300

    private_constant :MAX_GAP, :LARGE_RANGE_THRESHOLD

    def find(names_lower)
      suffixes_by_base = extract_suffixes(names_lower)
      suffixes_by_base.transform_values! do |suffixes|
        next if suffixes.empty?

        suffixes.sort!

        ranges = []
        range_start = 1
        current_max = suffixes[0]

        suffixes.each_cons(2) do |previous_suffix, current_suffix|
          if current_suffix - previous_suffix < MAX_GAP
            current_max = current_suffix
          else
            ranges << [current_max, current_max - range_start]
            range_start = current_suffix
            current_max = current_suffix
          end
        end
        ranges << [current_max, current_max - range_start]

        result = nil
        last_index = ranges.size - 1

        ranges.reverse_each.with_index do |(max_suffix, range_size), index|
          if index == last_index || range_size >= LARGE_RANGE_THRESHOLD
            result = max_suffix
            break
          end
        end

        result
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
