# frozen_string_literal: true

require "json"

module DiscourseAi
  module Utils
    class BestEffortJsonParser
      class << self
        def extract_key(helper_response, schema_type, schema_key)
          return helper_response unless helper_response.is_a?(String)

          schema_type = schema_type.to_sym
          schema_key = schema_key&.to_sym
          cleaned = remove_markdown_fences(helper_response.strip)

          parsed =
            try_parse(cleaned) || try_parse(fix_common_issues(cleaned)) ||
              manual_extract(cleaned, schema_key, schema_type)

          value = parsed.is_a?(Hash) ? parsed[schema_key.to_s] : parsed

          cast_value(value, schema_type)
        end

        private

        def remove_markdown_fences(text)
          return text unless text.match?(/^```(?:json)?\s*\n/i)

          text.gsub(/^```(?:json)?\s*\n/i, "").gsub(/\n```\s*$/, "")
        end

        def fix_common_issues(text)
          text.gsub(/(\w+):/, '"\1":').gsub(/'/, "\"")
        end

        def try_parse(text)
          JSON.parse(text)
        rescue JSON::ParserError
          nil
        end

        def manual_extract(text, key, schema_type)
          return default_for(schema_type) unless key

          case schema_type
          when :object
            extract_object(text, key.to_s)
          when :array, :string
            extract_scalar(text, key.to_s, schema_type)
          else
            default_for(schema_type)
          end
        end

        def extract_scalar(text, key, schema_type)
          patterns =
            if schema_type == :array
              [
                /"#{key}"\s*:\s*\[([^\]]+)\]/,
                /'#{key}'\s*:\s*\[([^\]]+)\]/,
                /#{key}\s*:\s*\[([^\]]+)\]/,
              ]
            else
              [
                /"#{key}"\s*:\s*"([^"]+)"/,
                /'#{key}'\s*:\s*'([^']+)'/,
                /#{key}\s*:\s*"([^"]+)"/,
                /#{key}\s*:\s*'([^']+)'/,
              ]
            end

          patterns.each do |pattern|
            match = text.match(pattern)
            next unless match

            value = match[1]
            return schema_type == :array ? parse_array(value) : value
          end

          default_for(schema_type)
        end

        def parse_array(value)
          JSON.parse("[#{value}]")
        rescue JSON::ParserError
          value.split(",").map { |item| item.strip.gsub(/^['"]|['"]$/, "") }
        end

        def extract_object(text, key)
          pattern = /("#{key}"|'#{key}'|#{key})\s*:\s*\{/
          match = text.match(pattern) or return {}

          start = match.end(0) - 1
          return {} unless text[start] == "{"

          end_pos = find_matching_brace(text, start)
          return {} unless end_pos

          obj_str = text[start..end_pos]
          try_parse(obj_str) || try_parse(fix_common_issues(obj_str)) || {}
        end

        def find_matching_brace(text, start_pos)
          brace_count = 0

          text[start_pos..-1].each_char.with_index do |char, idx|
            brace_count += 1 if char == "{"
            if char == "}"
              brace_count -= 1
              return start_pos + idx if brace_count.zero?
            end
          end
          nil
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
          else
            value.to_s
          end
        end

        def default_for(schema_type)
          schema_type == :array ? [] : schema_type == :object ? {} : ""
        end
      end
    end
  end
end
