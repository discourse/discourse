# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CategoryModerationGroups < Conversion::ProgressStep
        source { reads_table "category_moderation_groups", where: "group_id > 0" }

        processor do
          def process(item)
            IntermediateDB::CategoryModerationGroup.create(
              category_id: item[:category_id],
              group_id: item[:group_id],
            )
          end
        end
      end
    end
  end
end
