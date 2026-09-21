# frozen_string_literal: true

require "digest"

module DiscourseWorkflows
  module NodePacks
    module CanonicalJson
      module_function

      COSMETIC_NODE_KEYS = %w[examples subtitle description docs_url icon color label].freeze
      COSMETIC_PROPERTY_KEYS = %w[label description placeholder].freeze

      def dump(value)
        JSON.generate(sort(value))
      end

      def sha256(value)
        Digest::SHA256.hexdigest(dump(value))
      end

      def behavior_sha256(definition)
        sha256(remove_cosmetic(definition))
      end

      def sort(value)
        case value
        when Hash
          value
            .keys
            .map(&:to_s)
            .sort
            .to_h do |key|
              child = value.key?(key) ? value[key] : value[key.to_sym]
              [key, sort(child)]
            end
        when Array
          value.map { |entry| sort(entry) }
        else
          value
        end
      end

      def remove_cosmetic(value)
        return value unless value.is_a?(Hash)

        value.each_with_object({}) do |(key, child), result|
          key = key.to_s
          next if COSMETIC_NODE_KEYS.include?(key)

          result[key] = if key == "properties"
            child.to_h do |property_name, field|
              [property_name.to_s, remove_property_cosmetics(field)]
            end
          elsif key == "_effective"
            remove_effective_cosmetics(child)
          else
            remove_nested(child)
          end
        end
      end

      def remove_property_cosmetics(field)
        return remove_nested(field) unless field.is_a?(Hash)

        field.each_with_object({}) do |(key, child), result|
          key = key.to_s
          next if COSMETIC_PROPERTY_KEYS.include?(key)

          result[key] = if key == "options" && child.is_a?(Array)
            child.map { |option| remove_option_cosmetics(option) }
          else
            remove_nested(child)
          end
        end
      end

      def remove_option_cosmetics(option)
        return remove_nested(option) unless option.is_a?(Hash)

        result = remove_nested(option).except("label")
        if option["values"].is_a?(Hash)
          result["values"] = option["values"].to_h do |property_name, nested_field|
            [property_name.to_s, remove_property_cosmetics(nested_field)]
          end
        end
        result
      end

      def remove_effective_cosmetics(value)
        value = remove_nested(value)
        credential = value["credential"]
        value["credential"] = credential.except("label") if credential.is_a?(Hash)
        value
      end

      def remove_nested(value)
        case value
        when Hash
          value.to_h { |key, child| [key.to_s, remove_nested(child)] }
        when Array
          value.map { |entry| remove_nested(entry) }
        else
          value
        end
      end
    end
  end
end
