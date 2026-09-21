# frozen_string_literal: true

module DiscourseWorkflows
  module NodePacks
    class TemplateRenderer
      OMIT = Object.new.freeze

      def self.render(template, params: {}, response: nil, max_bytes: nil)
        rendered = new(params:, response:).render(template)
        rendered = nil if rendered.equal?(OMIT)
        if max_bytes && JSON.generate(rendered).bytesize > max_bytes
          raise DiscourseWorkflows::NodeError,
                I18n.t("discourse_workflows.node_packs.errors.request_too_large")
        end
        rendered
      end

      def initialize(params:, response:)
        @params = params
        @response = response
      end

      def render(value, row: nil)
        case value
        when Array
          value.map { |entry| render(entry, row:) }.reject { |entry| entry.equal?(OMIT) }
        when Hash
          render_hash(value.stringify_keys, row:)
        else
          value
        end
      end

      private

      def render_hash(value, row:)
        return placeholder(path_value(@params, value["$param"]), value) if value.key?("$param")
        return placeholder(path_value(row, value["$row"]), value) if value.key?("$row")
        return path_value(@response, value["$response"]) if value.key?("$response")
        return render_rows(value, row:) if value.key?("$rows")

        omit_empty = value["$omit_if_empty"] == true
        rendered =
          value
            .except("$omit_if_empty")
            .each_with_object({}) do |(key, child), result|
              child_value = render(child, row:)
              result[key] = child_value unless child_value.equal?(OMIT)
            end
        omit_empty && rendered.empty? ? OMIT : rendered
      end

      def render_rows(value, row:)
        rows = Array(path_value(@params, value["$rows"]))
        key_field = value["key"]
        if key_field.blank?
          return(
            rows
              .map { |entry| render(value["value"], row: entry) }
              .reject { |entry| entry.equal?(OMIT) }
          )
        end

        rows.each_with_object({}) do |entry, result|
          key = path_value(entry, key_field).to_s
          if key.blank? || result.key?(key)
            raise DiscourseWorkflows::NodeError,
                  I18n.t("discourse_workflows.node_packs.errors.duplicate_row_key")
          end
          rendered = render(value["value"], row: entry)
          result[key] = rendered unless rendered.equal?(OMIT)
        end
      end

      def placeholder(value, definition)
        definition["omit_if_blank"] && empty_value?(value) ? OMIT : value
      end

      def empty_value?(value)
        value.nil? || (value.respond_to?(:empty?) && value.empty?)
      end

      def path_value(value, path)
        path
          .to_s
          .split(".")
          .reduce(value) do |current, segment|
            case current
            when Hash
              if current.key?(segment)
                current[segment]
              elsif current.key?(segment.to_sym)
                current[segment.to_sym]
              end
            when Array
              break nil unless segment.match?(/\A(?:0|[1-9]\d*)\z/)

              index = segment.to_i
              break nil if index >= current.length

              current[index]
            else
              break nil
            end
          end
      end
    end
  end
end
