# frozen_string_literal: true

module DiscourseAi
  module Utils
    class BestEffortJsonParser
      class << self
        def extract_key(helper_response, schema_type, schema_key)
          return helper_response unless helper_response.is_a?(String)

          schema_type = schema_type.to_sym
          key = schema_key.to_s
          cleaned = remove_markdown_fences(helper_response.strip)

          parsed = best_effort_parse(cleaned, key)
          value = parsed.is_a?(Hash) ? parsed[key] : parsed

          cast_value(value, schema_type)
        end

        # Some providers deliver JSON whose string values had their control
        # characters unescaped by an outer JSON parse (real newlines inside
        # string values). Re-escaping them restores a parseable document.
        def escape_control_characters(text)
          text.gsub(/[\x00-\x1F]/) { |char| format("\\u%04x", char.ord) }
        end

        private

        # Parse attempts, in order:
        #  1. JsonCompleter: strict JSON that tolerates truncation, completing
        #     unclosed structures and strings.
        #  2. JsonCompleter over a control-character-escaped copy: recovers
        #     values containing real newlines/tabs.
        #  3. SmarterJSON: lenient parsing for single quotes, unquoted keys,
        #     prose-wrapped JSON, and other LLM formatting quirks.
        #
        # A candidate wins if it holds the schema key; a parseable document
        # missing the key is kept only as a last resort.
        def best_effort_parse(cleaned, key)
          attempts = [
            -> { JsonCompleter.parse(cleaned) },
            -> { JsonCompleter.parse(escape_control_characters(cleaned)) },
            -> { SmarterJSON.process_one(cleaned) },
          ]

          fallback = nil
          attempts.each do |attempt|
            candidate =
              begin
                attempt.call
              rescue StandardError
                nil
              end

            next if candidate.nil?
            return candidate if !candidate.is_a?(Hash) || candidate.key?(key)
            fallback ||= candidate
          end

          fallback
        end

        def remove_markdown_fences(text)
          return text unless text.match?(/^```(?:json)?\s*\n/i)

          text.gsub(/^```(?:json)?\s*\n/i, "").gsub(/\n```\s*$/, "")
        end

        def cast_value(value, schema_type)
          case schema_type
          when :array
            value.is_a?(Array) ? value : []
          when :object
            value.is_a?(Hash) ? value : {}
          when :boolean
            return value if [true, false, nil].include?(value)
            value.to_s.downcase == "true"
          when :integer, :number
            return value if value.is_a?(Numeric)
            Integer(value.to_s, exception: false) || Float(value.to_s, exception: false)
          else
            value.to_s
          end
        end
      end
    end
  end
end
