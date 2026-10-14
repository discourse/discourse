# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Matcher
        module Strategies
          # The `import_id` custom field written by the older import scripts.
          class ImportId
            FIELD_NAME = "import_id"

            def name
              "import_id"
            end

            def keys_for(kind, record)
              klass, column = custom_field(kind)
              { "import_id" => klass.where(column => record.id, :name => FIELD_NAME).pick(:value) }
            end

            def find_id(kind, keys)
              return if keys["import_id"].blank?

              klass, column = custom_field(kind)
              klass.where(name: FIELD_NAME, value: keys["import_id"].to_s).pick(column)
            end

            private

            def custom_field(kind)
              case kind
              when :category
                [::CategoryCustomField, :category_id]
              when :group
                [::GroupCustomField, :group_id]
              else
                raise ArgumentError, "unknown kind: #{kind}"
              end
            end
          end
        end
      end
    end
  end
end
