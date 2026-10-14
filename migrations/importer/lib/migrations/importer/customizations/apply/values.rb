# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Turns portable references back into ids of the target site.
        class Values
          def initialize(uploads, lookup)
            @uploads = uploads
            @lookup = lookup
          end

          def site_setting(name, value)
            return value unless value.is_a?(Hash)

            if value.key?("theme")
              @lookup.theme(value["theme"]).id
            elsif value.key?("color_scheme")
              @lookup.color_scheme!(value["color_scheme"]).id
            elsif value.key?("upload")
              @uploads.id_for(value)
            elsif value.key?("uploads")
              Array(value["uploads"]).map { |ref| @uploads.id_for(ref) }.join("|")
            elsif value.key?("groups")
              Array(value["groups"]).map { |group| @lookup.group_id(group) }.join("|")
            elsif value.key?("categories")
              Array(value["categories"]).map { |keys| @lookup.category_id(keys) }.join("|")
            elsif value.key?("objects")
              schema = ::SiteSetting.type_supervisor.type_hash(name.to_sym)[:schema]
              JSON.generate(objects(value["objects"], schema))
            else
              raise Error, "unsupported value: #{value.keys.join(", ")}"
            end
          end

          def objects(objects, schema)
            ObjectsUploads.transform(Array(objects), schema) do |value|
              value.is_a?(Hash) && value.key?("upload") ? @uploads.id_for(value) : value
            end
          end

          def upload(ref)
            @uploads.id_for(ref)
          end
        end
      end
    end
  end
end
