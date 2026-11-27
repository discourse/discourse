# frozen_string_literal: true

module DiscourseAi
  module Utils
    module DiffUtils
      class SimpleDiff
        LEVENSHTEIN_THRESHOLD = 2

        class Error < StandardError
        end

        class NoMatchError < Error
        end

        def self.apply(content, search, replace)
          new.apply(content, search, replace)
        end

        def apply(content, search, replace)
          raise ArgumentError, "content cannot be nil" if content.nil?
          raise ArgumentError, "search cannot be nil" if search.nil?
          raise ArgumentError, "replace cannot be nil" if replace.nil?
          raise ArgumentError, "search cannot be empty" if search.empty?

          return content.gsub(search, replace) if content.include?(search)

          lines = content.split("\n")
          search_lines = search.split("\n")

          # 1. Try exact matching
          match_positions =
            find_matches(lines.length, search_lines.length) do |line_idx, search_idx|
              lines[line_idx] == search_lines[search_idx]
            end

          if match_positions.empty?
            stripped_lines = lines.map(&:strip)
            stripped_search_lines = search_lines.map(&:strip)

            # 2. Try stripped matching
            match_positions =
              find_matches(lines.length, search_lines.length) do |line_idx, search_idx|
                stripped_lines[line_idx] == stripped_search_lines[search_idx]
              end

            # 3. Try non-contiguous line based stripped matching
            if match_positions.empty?
              if range = non_contiguous_match_range(stripped_lines, stripped_search_lines)
                first_match, last_match = range
                lines[first_match, last_match - first_match + 1] = replace.split("\n")
                return lines.join("\n")
              end
            end

            # 4. Try fuzzy matching
            if match_positions.empty?
              lstripped_lines = lines.map(&:lstrip)
              lstripped_search_lines = search_lines.map(&:lstrip)
              scratch = []

              match_positions =
                find_matches(lines.length, search_lines.length) do |line_idx, search_idx|
                  stripped_lines[line_idx] == stripped_search_lines[search_idx] ||
                    within_levenshtein_threshold?(
                      lstripped_lines[line_idx],
                      lstripped_search_lines[search_idx],
                      LEVENSHTEIN_THRESHOLD,
                      scratch,
                    )
                end
            end
          end

          # 5. Try block matching as last resort
          if match_positions.empty?
            if block_matches = find_block_matches(content, search)
              return replace_blocks(content, block_matches, replace)
            end
          end

          if match_positions.empty?
            raise NoMatchError, "Could not find a match for the search content"
          end

          # Replace matches in reverse order
          replacement_lines = replace.split("\n")
          match_positions.reverse_each { |pos| lines[pos, search_lines.length] = replacement_lines }

          lines.join("\n")
        end

        private

        def non_contiguous_match_range(stripped_lines, stripped_search_lines)
          first_idx = nil
          last_idx = nil
          search_index = 0

          stripped_lines.each_with_index do |stripped_line, idx|
            if stripped_search_lines[search_index] == "..."
              search_index += 1
              break if stripped_search_lines[search_index].nil?
            end
            if stripped_line == stripped_search_lines[search_index]
              first_idx ||= idx
              last_idx = idx
              search_index += 1
              return first_idx, last_idx if search_index == stripped_search_lines.length
            end
          end

          nil
        end

        def find_matches(lines_count, search_lines_count)
          matches = []
          max_index = lines_count - search_lines_count

          (0..max_index).each do |i|
            matches << i if (0...search_lines_count).all? { |j| yield(i + j, j) }
          end

          matches
        end

        def within_levenshtein_threshold?(
          s1,
          s2,
          max_distance = LEVENSHTEIN_THRESHOLD,
          scratch = []
        )
          if s1.ascii_only? && s2.ascii_only?
            within_ascii_levenshtein_threshold?(s1, s2, max_distance, scratch)
          else
            len1 = s1.length
            len2 = s2.length
            return false if (len1 - len2).abs > max_distance

            within_codepoint_levenshtein_threshold?(
              s1.codepoints,
              s2.codepoints,
              max_distance,
              scratch,
            )
          end
        end

        def within_ascii_levenshtein_threshold?(s1, s2, max_distance, scratch)
          len1 = s1.bytesize
          len2 = s2.bytesize
          return false if (len1 - len2).abs > max_distance

          prefix = 0
          min_len = len1 < len2 ? len1 : len2
          prefix += 1 while prefix < min_len && s1.getbyte(prefix) == s2.getbyte(prefix)

          suffix = 0
          rem_min = min_len - prefix
          while suffix < rem_min && s1.getbyte(len1 - 1 - suffix) == s2.getbyte(len2 - 1 - suffix)
            suffix += 1
          end

          m = len1 - prefix - suffix
          n = len2 - prefix - suffix
          return n <= max_distance if m == 0
          return m <= max_distance if n == 0
          return false if (m - n).abs > max_distance

          inf = max_distance + 1
          scratch.fill(inf, 0, n + 1)
          init_limit = n < max_distance ? n : max_distance
          j = 0
          while j <= init_limit
            scratch[j] = j
            j += 1
          end

          i = 1
          while i <= m
            lo = i - max_distance
            lo = 0 if lo < 0
            hi = i + max_distance
            hi = n if hi > n

            if lo == 0
              diag = scratch[0]
              scratch[0] = i
              left = i
              row_min = i
              j = 1
            else
              diag = scratch[lo - 1]
              left = inf
              row_min = inf
              j = lo
            end

            c1 = s1.getbyte(prefix + i - 1)
            while j <= hi
              up = scratch[j]
              cost = c1 == s2.getbyte(prefix + j - 1) ? 0 : 1
              del = up + 1
              ins = left + 1
              sub = diag + cost
              val = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub)
              diag = up
              left = val
              scratch[j] = val
              row_min = val if val < row_min
              j += 1
            end

            scratch[lo - 1] = inf if lo > 0
            return false if row_min > max_distance

            i += 1
          end

          scratch[n] <= max_distance
        end

        def within_codepoint_levenshtein_threshold?(cp1, cp2, max_distance, scratch)
          len1 = cp1.length
          len2 = cp2.length

          prefix = 0
          min_len = len1 < len2 ? len1 : len2
          prefix += 1 while prefix < min_len && cp1[prefix] == cp2[prefix]

          suffix = 0
          rem_min = min_len - prefix
          suffix += 1 while suffix < rem_min && cp1[len1 - 1 - suffix] == cp2[len2 - 1 - suffix]

          m = len1 - prefix - suffix
          n = len2 - prefix - suffix
          return n <= max_distance if m == 0
          return m <= max_distance if n == 0
          return false if (m - n).abs > max_distance

          inf = max_distance + 1
          scratch.fill(inf, 0, n + 1)
          init_limit = n < max_distance ? n : max_distance
          j = 0
          while j <= init_limit
            scratch[j] = j
            j += 1
          end

          i = 1
          while i <= m
            lo = i - max_distance
            lo = 0 if lo < 0
            hi = i + max_distance
            hi = n if hi > n

            if lo == 0
              diag = scratch[0]
              scratch[0] = i
              left = i
              row_min = i
              j = 1
            else
              diag = scratch[lo - 1]
              left = inf
              row_min = inf
              j = lo
            end

            c1 = cp1[prefix + i - 1]
            while j <= hi
              up = scratch[j]
              cost = c1 == cp2[prefix + j - 1] ? 0 : 1
              del = up + 1
              ins = left + 1
              sub = diag + cost
              val = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub)
              diag = up
              left = val
              scratch[j] = val
              row_min = val if val < row_min
              j += 1
            end

            scratch[lo - 1] = inf if lo > 0
            return false if row_min > max_distance

            i += 1
          end

          scratch[n] <= max_distance
        end

        def find_block_matches(content, search)
          content_blocks = extract_blocks(content)
          search_blocks = extract_blocks(search)

          return nil if content_blocks.empty? || search_blocks.empty?

          matches = []
          search_blocks.each do |search_block|
            content_blocks.each do |content_block|
              matches << content_block if content_block[:text] == search_block[:text]
            end
          end

          matches.empty? ? nil : matches
        end

        def extract_blocks(text)
          lines = text.split("\n")
          blocks = []
          current_block = []
          block_start = nil

          lines.each_with_index do |line, index|
            if line =~ /^[^\s]/
              # Save previous block if exists
              if !current_block.empty?
                current_block << line
                blocks << {
                  start: block_start,
                  length: current_block.length,
                  text: current_block.join("\n").strip,
                }
                current_block = []
              else
                current_block = [line]
                block_start = index
              end
            else
              # Continue current block
              current_block << line if current_block.any?
            end
          end

          # Add final block
          if !current_block.empty?
            blocks << {
              start: block_start,
              length: current_block.length,
              text: current_block.join("\n").strip,
            }
          end

          blocks
        end

        def replace_blocks(content, blocks, replace)
          lines = content.split("\n")

          # Sort blocks in reverse order to maintain correct positions
          blocks
            .sort_by { |b| -b[:start] }
            .each_with_index do |block, index|
              replacement = index.zero? ? replace : ""
              lines.slice!(block[:start], block[:length])
              lines.insert(block[:start], *replacement.split("\n"))
            end

          lines.join("\n")
        end
      end
    end
  end
end
