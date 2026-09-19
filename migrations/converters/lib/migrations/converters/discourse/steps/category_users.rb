# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class CategoryUsers < Conversion::Step
        source { reads_table "category_users", where: "user_id > 0" }

        processor do
          def process(item)
            IntermediateDB::CategoryUser.create(
              category_id: item[:category_id],
              last_seen_at: item[:last_seen_at],
              notification_level: item[:notification_level],
              user_id: item[:user_id],
            )
          end
        end
      end
    end
  end
end
