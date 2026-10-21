# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      class Matcher
        module Strategies
          # The `import_id` custom field written by `script/import_scripts` and
          # `script/bulk_import`.
          class ImportId
            FIELD_NAME = "import_id"

            def name
              "import_id"
            end

            def keys_for(kind, record)
              klass, column = custom_field(kind)
              return {} if klass.nil?

              { "import_id" => klass.where(column => record.id, :name => FIELD_NAME).pick(:value) }
            end

            def find_id(kind, keys)
              klass, column = custom_field(kind)
              return if klass.nil? || keys["import_id"].blank?

              klass.where(name: FIELD_NAME, value: keys["import_id"].to_s).pick(column)
            end

            private

            # Tags have no custom fields to hold an import id.
            def custom_field(kind)
              case kind
              when :category
                [::CategoryCustomField, :category_id]
              when :group
                [::GroupCustomField, :group_id]
              when :topic
                [::TopicCustomField, :topic_id]
              when :post
                [::PostCustomField, :post_id]
              when :user
                [::UserCustomField, :user_id]
              when :tag
                nil
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
