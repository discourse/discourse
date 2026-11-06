# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        class ColorSchemes
          def initialize(values)
            @values = values
          end

          def call(item)
            scheme = find_scheme(item)
            base_name = ::ColorScheme::NAMES_TO_ID_MAP.key(scheme.base_scheme_id)

            {
              "name" => scheme.name,
              "theme" => scheme.theme_id ? @values.theme_ref(scheme.theme) : nil,
              "base_scheme" => base_name,
              "user_selectable" => scheme.user_selectable,
              "colors" => scheme.colors.to_h { |color| [color.name, color.hex] },
            }.merge(item.slice("target", "note"))
          end

          private

          def find_scheme(item)
            schemes = ::ColorScheme.where(name: item["name"]).to_a
            if (owner = item["theme"]).is_a?(Hash)
              schemes.select! do |scheme|
                next false if scheme.theme.nil?
                if owner["system_id"]
                  scheme.theme_id == owner["system_id"].to_i
                else
                  scheme.theme.name == owner["name"]
                end
              end
            end
            raise Error, "color palette does not exist" if schemes.empty?

            standalone = schemes.select { |s| s.theme_id.nil? }
            schemes = standalone if standalone.any?
            if schemes.size > 1
              raise Error,
                    "#{schemes.size} color palettes have this name; rename them to tell them apart"
            end
            schemes.first
          end
        end
      end
    end
  end
end
