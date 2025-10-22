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

          ### TODO implement me

          # 1. Try exact matching
          match_positions =
            find_matches(lines, search_lines) { |line, search_line| line == search_line }

          # 2. Try stripped matching
          if match_positions.empty?
            match_positions =
              find_matches(lines, search_lines) do |line, search_line|
                line.strip == search_line.strip
              end
          end

          # 3. Try non-contiguous line based stripped matching
          if match_positions.empty?
            if range = non_contiguous_match_range(lines, search_lines)
              first_match, last_match = range
              lines.slice!(first_match, last_match - first_match + 1)
              lines.insert(first_match, *replace.split("\n"))
              return lines.join("\n")
            end
          end

          # 4. Try fuzzy matching
          if match_positions.empty?
            match_positions =
              find_matches(lines, search_lines) do |line, search_line|
                fuzzy_match?(line, search_line)
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
          match_positions.sort.reverse.each do |pos|
            lines.slice!(pos, search_lines.length)
            lines.insert(pos, *replace.split("\n"))
          end

          lines.join("\n")
        end

        private

        def non_contiguous_match_range(lines, search_lines)
          first_idx = nil
          last_idx = nil
          search_index = 0

          lines.each_with_index do |line, idx|
            if search_lines[search_index].strip == "..."
              search_index += 1
              break if search_lines[search_index].nil?
            end
            if line.strip == search_lines[search_index].strip
              first_idx ||= idx
              last_idx = idx
              search_index += 1
              return first_idx, last_idx if search_index == search_lines.length
            end
          end

          nil
        end

        def find_matches(lines, search_lines)
          matches = []
          max_index = lines.length - search_lines.length

          (0..max_index).each do |i|
            if (0...search_lines.length).all? { |j| yield(lines[i + j], search_lines[j]) }
              matches << i
            end
          end

          matches
        end

        def fuzzy_match?(line, search_line)
          return true if line.strip == search_line.strip
          s1 = line.lstrip
          s2 = search_line.lstrip
          levenshtein_distance(s1, s2) <= LEVENSHTEIN_THRESHOLD
        end

        def levenshtein_distance(s1, s2)
          m = s1.length
          n = s2.length
          d = Array.new(m + 1) { Array.new(n + 1, 0) }

          (0..m).each { |i| d[i][0] = i }
          (0..n).each { |j| d[0][j] = j }

          (1..m).each do |i|
            (1..n).each do |j|
              cost = s1[i - 1] == s2[j - 1] ? 0 : 1
              d[i][j] = [d[i - 1][j] + 1, d[i][j - 1] + 1, d[i - 1][j - 1] + cost].min
            end
          end

          d[m][n]
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
