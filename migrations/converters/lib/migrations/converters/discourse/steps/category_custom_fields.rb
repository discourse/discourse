# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CategoryCustomFields < Conversion::Step
        source { reads_table "category_custom_fields" }

        processor do
          def process(item)
            IntermediateDB::CategoryCustomField.create(
              category_id: item[:category_id],
              name: item[:name],
              value: item[:value],
            )
          end
        end
      end
    end
  end
end
