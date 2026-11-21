# frozen_string_literal: true

module Migrations
  module Importer
    module Customizations
      module Export
        # Reads the listed group/category attributes, with upload columns
        # turned into upload references.
        module Attributes
          def self.export(record, names, allowed, values)
            upload_columns = Plan::Rules::UPLOAD_ATTRIBUTES.invert

            (Array(names) - [Plan::Rules::CATEGORY_PERMISSIONS]).to_h do |name|
              column = upload_columns.fetch(name, name)
              raise Error, "attribute '#{name}' can't be transferred" if allowed.exclude?(column)

              value = record.read_attribute(column)
              value = values.upload(value) if upload_columns.key?(name)
              [name, value]
            end
          end
        end
      end
    end
  end
end
