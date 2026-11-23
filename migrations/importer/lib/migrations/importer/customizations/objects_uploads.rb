# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      # Walks `objects` setting values and replaces every value of an `upload`
      # property, following nested `objects` properties.
      module ObjectsUploads
        def self.transform(objects, schema, &block)
          return objects if !objects.is_a?(Array) || schema.blank?

          properties = schema.deep_symbolize_keys[:properties] || {}
          walk(objects.deep_dup, properties, &block)
        end

        def self.walk(objects, properties, &block)
          objects.each do |object|
            next unless object.is_a?(Hash)

            properties.each do |property_name, attributes|
              key = [property_name.to_s, property_name.to_sym].find { |k| object.key?(k) }
              next if key.nil?

              case attributes[:type]
              when "upload"
                object[key] = block.call(object[key])
              when "objects"
                nested = object[key]
                if nested.is_a?(Array) && attributes.dig(:schema, :properties)
                  walk(nested, attributes[:schema][:properties], &block)
                end
              end
            end
          end
        end
        private_class_method :walk
      end
    end
  end
end
