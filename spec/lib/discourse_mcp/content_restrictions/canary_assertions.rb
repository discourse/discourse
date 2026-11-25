# frozen_string_literal: true

require "cgi"

module McpContentCanaries
  module Assertions
    def expect_clean(response, data, cell: "restricted output")
      serialized = JSON.generate(response)
      expect(response.fetch("status")).to be < 500, "#{cell}: server error"
      expect(response.fetch("headers").keys.map(&:downcase)).not_to include("www-authenticate"),
      "#{cell}: authentication challenge"
      normalized = output_strings(response).map { |value| normalize_canary_text(value) }
      leaked_tokens =
        data.restricted_tokens.select do |token_value|
          forms = [token_value, token_value.split.last].map { |value| normalize_canary_text(value) }
          serialized.include?(token_value) ||
            normalized.any? { |value| forms.any? { |form| value.include?(form) } }
        end
      expect(leaked_tokens).to eq([]),
      "#{cell}: RED restricted canary tokens #{leaked_tokens.inspect}"
      data.restricted_category_text.each do |text|
        expect(normalized).not_to include(a_string_including(normalize_canary_text(text))),
        "#{cell}: restricted category text #{text.inspect}"
      end
      data.restricted_urls.each do |url|
        expect(serialized).not_to include(url), "#{cell}: restricted URL #{url}"
      end
      (data.restricted_ids - data.contextual_category_ids).each do |id|
        expect(serialized).not_to match(/(?<!\d)#{id}(?!\d)/), "#{cell}: restricted ID #{id}"
      end
      leaked_category_ids =
        category_identifiers(response) & data.contextual_category_ids.map(&:to_s)
      expect(leaked_category_ids).to eq([]),
      "#{cell}: restricted category IDs #{leaked_category_ids.inspect}"
    end

    def expect_blocked(response, server_version:)
      message = I18n.t("mcp.errors.content_policy_blocked")
      expected =
        if response.fetch("status") == 200
          {
            "status" => 200,
            "headers" => {
            },
            "body" => {
              "jsonrpc" => "2.0",
              "id" => 1,
              "result" => {
                "content" => [{ "type" => "text", "text" => message }],
                "isError" => true,
                "resultType" => "complete",
                "_meta" => {
                  "io.modelcontextprotocol/serverInfo" => {
                    "name" => "discourse",
                    "version" => server_version,
                  },
                },
              },
            },
          }
        else
          {
            "status" => 400,
            "headers" => {
            },
            "body" => {
              "jsonrpc" => "2.0",
              "id" => 1,
              "error" => {
                "code" => -32_602,
                "message" => message,
              },
            },
          }
        end
      expect(response).to eq(expected)
    end

    def schema_identifier_fields(schema, prefix = "")
      fields =
        schema
          .fetch("properties", {})
          .flat_map do |name, child|
            path = prefix.empty? ? name : "#{prefix}.#{name}"
            identifiers = name.match?(/(?:\Aid\z|_ids?\z|\Adraft_key\z|\Auri\z)/) ? [path] : []
            identifiers + schema_identifier_fields(child, path)
          end
      if schema["items"].is_a?(Hash)
        fields.concat(schema_identifier_fields(schema.fetch("items"), "#{prefix}[]"))
      end
      %w[allOf anyOf oneOf].each do |keyword|
        schema
          .fetch(keyword, [])
          .each { |child| fields.concat(schema_identifier_fields(child, prefix)) }
      end
      fields.uniq
    end

    def arguments_with_identifier(arguments, fixture, field, identifier)
      result = arguments.deep_merge(fixture.fetch("id_arguments", {}).fetch(field, {}))
      path = field.gsub("[]", ".0").split(".").map { |key| key == "0" ? 0 : key }
      replace_argument_identifier(result, path, identifier)
    end

    def expect_fixture_id_fields(fixture, id_keys)
      expect(id_keys - fixture.fetch("ids").keys).to eq([])
    end

    def expect_no_cooking(operation)
      expect(operation.fetch("cooks_nothing")).to eq(true)
      expect(operation.fetch("raw")).to be_present
    end

    def response_without_request_echo(response, field:, supplied:, replacement:, echoes:)
      copy = Marshal.load(Marshal.dump(response))
      echoes
        .fetch(field, [])
        .each { |path| replace_echo_at_path(copy, path, supplied, replacement) }
      copy
    end

    private

    # Existing category IDs can also be protocol IDs or counters; seeded high IDs retain the full-response check.
    def category_identifiers(value, in_category: false)
      case value
      when Hash
        value.flat_map do |key, child|
          normalized_key = normalize_canary_text(key.to_s)
          if normalized_key.match?(/categor(?:y|ies)ids?\z/) || (in_category && key.to_s == "id")
            JSON.generate(child).scan(/\d+/)
          else
            indexed_category = in_category && key.to_s.match?(/\A\d+\z/)
            identifiers = indexed_category ? [key.to_s] : []
            identifiers +
              category_identifiers(
                child,
                in_category: indexed_category || %w[category categories].include?(normalized_key),
              )
          end
        end
      when Array
        value.flat_map { |child| category_identifiers(child, in_category:) }
      when String
        begin
          category_identifiers(JSON.parse(value), in_category:)
        rescue JSON::ParserError
          []
        end
      when Integer
        in_category ? [value.to_s] : []
      else
        []
      end
    end

    def normalize_canary_text(value)
      CGI.unescapeHTML(value).unicode_normalize(:nfkc).downcase.gsub(/[^[:alnum:]]/, "")
    end

    def output_strings(value)
      case value
      when Hash
        value.flat_map { |key, child| [key.to_s, *output_strings(child)] }
      when Array
        value.flat_map { |child| output_strings(child) }
      when String
        strings = [value]
        begin
          parsed = JSON.parse(value)
          strings.concat(output_strings(parsed)) if parsed.is_a?(Hash) || parsed.is_a?(Array)
        rescue JSON::ParserError
          # Text parts can contain either JSON documents or ordinary prose.
        end
        strings
      else
        []
      end
    end

    def replace_argument_identifier(value, path, identifier)
      key, *rest = path
      copy = value.deep_dup
      if rest.empty?
        copy[key] = identifier
      else
        child = copy[key] || (rest.first.is_a?(Integer) ? [] : {})
        copy[key] = replace_argument_identifier(child, rest, identifier)
      end
      copy
    end

    def replace_echo_at_path(value, path, supplied, replacement)
      key, *rest = path
      if value.is_a?(String)
        return replace_json_echo(value, key, supplied, replacement) if rest.empty?
        return value
      end
      return value unless value.is_a?(Hash) || value.is_a?(Array)
      return value if value.is_a?(Array) && !key.is_a?(Integer)
      return value if value.is_a?(Hash) && !value.key?(key)

      if rest.empty?
        value[key] = replacement if value[key] == supplied
      else
        value[key] = replace_echo_at_path(value[key], rest, supplied, replacement)
      end
      value
    end

    def replace_json_echo(text, field, supplied, replacement)
      parsed = JSON.parse(text)
      return text unless parsed.is_a?(Hash) && parsed[field] == supplied

      depth = 0
      tokens =
        text.to_enum(:scan, /"(?:\\.|[^"\\])*"|[{}\[\]:,]|[^\s{}\[\]:,]+/).map { Regexp.last_match }
      tokens.each_with_index do |token, index|
        case token[0]
        when "{", "["
          depth += 1
        when "}", "]"
          depth -= 1
        else
          next unless depth == 1 && token[0] == JSON.generate(field)
          next unless tokens[index + 1]&.[](0) == ":"
          echoed = tokens[index + 2]
          next unless echoed && JSON.parse(echoed[0]) == supplied
          return text[0...echoed.begin(0)] + JSON.generate(replacement) + text[echoed.end(0)..]
        end
      end
      text
    rescue JSON::ParserError
      text
    end
  end
end
