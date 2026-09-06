# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class BadgeGroupings < Conversion::Step
        source do
          # Skip the system badge groupings.
          reads_table "badge_groupings", where: "id NOT IN (1, 2, 3, 4, 5)"
        end

        processor do
          def process(item)
            IntermediateDB::BadgeGrouping.create(
              original_id: item[:id],
              name: item[:name],
              description: item[:description],
              created_at: item[:created_at],
              position: item[:position],
            )
          end
        end
      end
    end
  end
end
