# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Apply
        # Applies the listed group/category attributes. Only allowed columns are
        # written, whatever the manifest contains.
        module Attributes
          def self.desired(entry, allowed, values)
            upload_columns = Plan::Rules::UPLOAD_ATTRIBUTES.invert
            attributes = entry["attributes"] || {}
            raise Error, "attributes must be a mapping" unless attributes.is_a?(Hash)

            attributes
              .except(Plan::Rules::CATEGORY_PERMISSIONS)
              .to_h do |name, value|
                column = upload_columns.fetch(name, name)
                raise Error, "attribute '#{name}' can't be transferred" if allowed.exclude?(column)

                value = values.upload(value) if upload_columns.key?(name)
                [column, value]
              end
          end

          def self.differences(record, desired)
            desired.reject do |column, value|
              current = record.read_attribute(column)
              value = record.class.type_for_attribute(column).cast(value)
              current == value || Plan::Rules.blank_equal?(current, value)
            end
          end
        end
      end
    end
  end
end
