# frozen_string_literal: true

require "yaml"

module Migrations
  module Importer
    module Customizations
      # The editable YAML file that selects what to transfer and where it goes.
      # Items name things by natural keys only; values are read from the site
      # at export time.
      class Plan
        FORMAT_VERSION = 1
        SECTIONS = %w[
          site_settings
          themes
          color_schemes
          groups
          categories
          translation_overrides
        ].freeze
        TARGETS = %w[template import skip].freeze
        APPLY_TARGETS = %w[template import].freeze

        attr_reader :data

        def self.load(path)
          raise Error, "Plan file not found: #{path}" unless File.exist?(path)

          data = YAML.safe_load_file(path)
          new(data)
        rescue Psych::SyntaxError => e
          raise Error, "Plan file is not valid YAML: #{e.message}"
        end

        def initialize(data)
          @data = data
          validate!
        end

        def items(section)
          Array(@data[section])
        end

        def exportable_items(section)
          items(section).reject { |item| item["target"] == "skip" }
        end

        # Dumps a plan hash; `trailer` lines are appended as YAML comments so a
        # human sees them without them becoming part of the data.
        def self.dump(data, trailer: [])
          yaml = YAML.dump(data)
          return yaml if trailer.empty?

          yaml + "\n" + trailer.map { |line| line.empty? ? "#" : "# #{line}" }.join("\n") + "\n"
        end

        private

        def validate!
          raise Error, "Plan must be a YAML mapping" unless @data.is_a?(Hash)

          version = @data["format_version"]
          if version != FORMAT_VERSION
            raise Error, "Unsupported plan format_version: #{version.inspect}"
          end

          unknown = @data.keys - SECTIONS - ["format_version"]
          raise Error, "Unknown plan sections: #{unknown.join(", ")}" if unknown.any?

          SECTIONS.each do |section|
            value = @data[section]
            next if value.nil?
            raise Error, "Plan section '#{section}' must be a list" unless value.is_a?(Array)

            value.each_with_index { |item, index| validate_item!(section, item, index) }
          end
        end

        def validate_item!(section, item, index)
          where = "#{section}[#{index}]"
          raise Error, "#{where} must be a mapping" unless item.is_a?(Hash)

          if TARGETS.exclude?(item["target"])
            raise Error, "#{where}: target must be one of #{TARGETS.join(", ")}"
          end

          case section
          when "site_settings", "themes", "color_schemes"
            raise Error, "#{where}: name is required" if item["name"].blank?
          when "groups"
            if item["name"].blank? && item["match"].blank?
              raise Error, "#{where}: name or match is required"
            end
          when "categories"
            raise Error, "#{where}: match is required" if item["match"].blank?
          when "translation_overrides"
            if item["locale"].blank? || item["key"].blank?
              raise Error, "#{where}: locale and key are required"
            end
          end

          if item.key?("attributes") && !item["attributes"].is_a?(Array)
            raise Error, "#{where}: attributes must be a list"
          end
        end
      end
    end
  end
end
