# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TagGroups < Conversion::Step
        source { reads_table "tag_groups" }

        processor do
          def process(item)
            IntermediateDB::TagGroup.create(
              original_id: item[:id],
              created_at: item[:created_at],
              name: item[:name],
              one_per_topic: item[:one_per_topic],
              parent_tag_id: item[:parent_tag_id],
            )
          end
        end
      end
    end
  end
end
