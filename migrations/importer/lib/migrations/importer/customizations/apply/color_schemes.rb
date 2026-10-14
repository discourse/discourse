# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        class ColorSchemes
          HEX = /\A[0-9a-f]{3}([0-9a-f]{3})?\z/i

          def initialize(lookup, dry_run:)
            @lookup = lookup
            @dry_run = dry_run
          end

          def call(entry)
            colors = colors(entry)
            attributes = {
              "base_scheme_id" => ::ColorScheme::NAMES_TO_ID_MAP[entry["base_scheme"]],
              "user_selectable" => entry["user_selectable"] == true,
              "theme_id" => entry["theme"] ? @lookup.theme(entry["theme"]).id : nil,
            }

            scheme = @lookup.color_scheme({ "name" => entry["name"], "theme" => entry["theme"] })
            if scheme.nil?
              return :changed, "would be created" if @dry_run
              create(entry["name"], attributes, colors)
              return :changed, "created"
            end

            current_colors = scheme.colors.to_h { |color| [color.name, color.hex.downcase] }
            same_attributes = attributes.all? { |key, value| scheme.read_attribute(key) == value }
            return :unchanged if same_attributes && current_colors == colors

            update(scheme, attributes, colors) unless @dry_run
            :changed
          end

          private

          def colors(entry)
            colors = entry["colors"]
            raise Error, "colors must be a mapping" unless colors.is_a?(Hash)

            colors.to_h do |name, hex|
              raise Error, "invalid color #{name}: #{hex.inspect}" unless HEX.match?(hex.to_s)
              [name.to_s, hex.downcase]
            end
          end

          def create(name, attributes, colors)
            scheme = ::ColorScheme.new(name:)
            scheme.assign_attributes(attributes)
            scheme.colors = colors.map { |color_name, hex| { name: color_name, hex: } }
            scheme.save!
          end

          def update(scheme, attributes, colors)
            ::ColorScheme.transaction do
              existing = scheme.color_scheme_colors.index_by(&:name)
              colors.each do |name, hex|
                if (color = existing.delete(name))
                  color.update!(hex:) if color.hex.downcase != hex
                else
                  scheme.color_scheme_colors.create!(name:, hex:)
                end
              end
              existing.each_value(&:destroy!)

              scheme.assign_attributes(attributes)
              scheme.save!
            end
          end
        end
      end
    end
  end
end
