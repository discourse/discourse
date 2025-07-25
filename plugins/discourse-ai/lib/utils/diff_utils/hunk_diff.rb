# frozen_string_literal: true
# Inspired by Aider https://github.com/Aider-AI/aider

module DiscourseAi
  module Utils
    module DiffUtils
      class HunkDiff
        class DiffError < StandardError
          attr_reader :original_text, :diff_text, :context

          def initialize(message, original_text:, diff_text:, context: {})
            @original_text = original_text
            @diff_text = diff_text
            @context = context
            super(message)
          end

          def to_llm_message
            original_text = @original_text
            original_text = @original_text[0..1000] + "..." if @original_text.length > 1000

            <<~MESSAGE
            #{message}

            Original text:
            ```
            #{original_text}
            ```

            Attempted diff:
            ```
            #{diff_text}
            ```

            #{context_message}

            Please provide a corrected diff that:
            1. Has the correct context lines
            2. Contains all necessary removals (-) and additions (+)
          MESSAGE
          end

          private

          def context_message
            return "" if context.empty?

            context.map { |key, value| "#{key}: #{value}" }.join("\n")
          end
        end

        class NoMatchingContextError < DiffError
          def initialize(original_text:, diff_text:)
            super(
              "Could not find the context lines in the original text",
              original_text: original_text,
              diff_text: diff_text,
            )
          end
        end

        class AmbiguousMatchError < DiffError
          def initialize(original_text:, diff_text:)
            super(
              "Found multiple possible locations for this change",
              original_text: original_text,
              diff_text: diff_text,
            )
          end
        end

        class MalformedDiffError < DiffError
          def initialize(original_text:, diff_text:, issue:)
            super(
              "The diff format is invalid",
              original_text: original_text,
              diff_text: diff_text,
              context: {
                "Issue" => issue,
              },
            )
          end
        end

        def self.apply(text, diff)
          new(text, diff).apply
        end

        def initialize(text, diff)
          @text = text.encode(universal_newline: true)
          @diff = diff.encode(universal_newline: true)
          @text = @text + "\n" unless @text.end_with?("\n")
        end

        def apply
          if multiple_hunks?
            apply_multiple_hunks
          else
            apply_single_hunk
          end
        end

        private

        attr_reader :text, :diff

        def multiple_hunks?
          diff.match?(/^\@\@.*\@\@$\n/)
        end

        def apply_multiple_hunks
          result = text
          hunks = diff.split(/^\@\@.*\@\@$\n/)

          hunks.each do |hunk|
            next if hunk.blank?
            result = self.class.new(result, hunk).apply
          end

          result
        end

        def apply_single_hunk
          diff_lines = parse_diff_lines
          validate_diff_format!(diff_lines)

          return text.strip + "\n" + diff.strip if context_only?(diff_lines)

          lines_to_match = extract_context_lines(diff_lines)
          match_start, match_end = find_unique_match(lines_to_match)

          build_result(match_start, match_end, diff_lines)
        end

        def parse_diff_lines
          diff.lines.map do |line|
            marker = line[0]
            content = line[1..]

            if !["-", "+", " "].include?(marker)
              marker = " "
              content = line
            end

            [marker, content]
          end
        end

        def validate_diff_format!(diff_lines)
          if diff_lines.empty?
            raise MalformedDiffError.new(
                    original_text: text,
                    diff_text: diff,
                    issue: "Diff is empty",
                  )
          end
        end

        def context_only?(diff_lines)
          diff_lines.all? { |marker, _| marker == " " }
        end

        def extract_context_lines(diff_lines)
          diff_lines.select { |marker, _| ["-", " "].include?(marker) }.map(&:last)
        end

        def find_unique_match(context_lines)
          return 0, 0 if context_lines.empty?

          pattern = context_lines.map { |line| "^\\s*" + Regexp.escape(line.strip) + "\s*$\n" }.join
          matches =
            text
              .enum_for(:scan, /#{pattern}/m)
              .map do
                match = Regexp.last_match
                [match.begin(0), match.end(0)]
              end

          case matches.length
          when 0
            raise NoMatchingContextError.new(original_text: text, diff_text: diff)
          when 1
            matches.first
          else
            raise AmbiguousMatchError.new(original_text: text, diff_text: diff)
          end
        end

        def build_result(match_start, match_end, diff_lines)
          new_hunk = +""
          diff_lines_index = 0

          text[match_start..match_end].lines.each do |line|
            diff_marker, diff_content = diff_lines[diff_lines_index]

            while diff_marker == "+"
              new_hunk << diff_content
              diff_lines_index += 1
              diff_marker, diff_content = diff_lines[diff_lines_index]
            end

            new_hunk << line if diff_marker == " "

            diff_lines_index += 1
          end

          # Handle any remaining additions
          append_remaining_additions(new_hunk, diff_lines, diff_lines_index)

          combine_result(match_start, match_end, new_hunk)
        end

        def append_remaining_additions(new_hunk, diff_lines, diff_lines_index)
          diff_marker, diff_content = diff_lines[diff_lines_index]
          while diff_marker == "+"
            diff_lines_index += 1
            new_hunk << diff_content
            diff_marker, diff_content = diff_lines[diff_lines_index]
          end
        end

        def combine_result(match_start, match_end, new_hunk)
          (text[0...match_start].to_s + new_hunk + text[match_end..-1].to_s).strip
        end
      end
    end
  end
end
