# frozen_string_literal: true

module DiscourseAi
  module Completions
    class ToolArgumentsParser
      class << self
        def parse(arguments)
          return arguments.deep_symbolize_keys if arguments.is_a?(Hash)

          normalized_arguments = arguments.to_s.strip
          return {} if normalized_arguments.blank?

          JSON.parse(normalized_arguments, symbolize_names: true)
        rescue JSON::ParserError => error
          repaired_arguments(normalized_arguments).each do |repaired_arguments|
            next if repaired_arguments == normalized_arguments

            begin
              return JSON.parse(repaired_arguments, symbolize_names: true)
            rescue JSON::ParserError
              next
            end
          end

          raise error
        end

        private

        def repaired_arguments(arguments)
          missing_opening_brace = repair_missing_opening_brace(arguments)
          candidates = [missing_opening_brace, repair_missing_closing_braces(arguments)]

          if missing_opening_brace != arguments
            candidates << repair_missing_closing_braces(missing_opening_brace)
          end

          candidates.uniq
        end

        def repair_missing_opening_brace(arguments)
          return arguments if arguments.start_with?("{") || !arguments.include?(":")

          if arguments.start_with?("\"")
            "{#{arguments}"
          elsif arguments.match?(/\A[a-zA-Z_][a-zA-Z0-9_]*"\s*:/)
            "{\"#{arguments}"
          else
            arguments
          end
        end

        def repair_missing_closing_braces(arguments)
          return arguments if !arguments.start_with?("{")

          unclosed_braces = unclosed_object_brace_count(arguments)
          return arguments if unclosed_braces <= 0

          arguments + ("}" * unclosed_braces)
        end

        def unclosed_object_brace_count(arguments)
          unclosed_braces = 0
          escaped = false
          in_string = false

          arguments.each_char do |character|
            if escaped
              escaped = false
            elsif character == "\\" && in_string
              escaped = true
            elsif character == '"'
              in_string = !in_string
            elsif !in_string && character == "{"
              unclosed_braces += 1
            elsif !in_string && character == "}"
              unclosed_braces -= 1
            end
          end

          unclosed_braces
        end
      end
    end
  end
end
