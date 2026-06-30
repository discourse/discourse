# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TagUsers < Conversion::ProgressStep
        source { reads_table "tag_users", where: "user_id > 0" }

        processor do
          def process(item)
            IntermediateDB::TagUser.create(
              tag_id: item[:tag_id],
              user_id: item[:user_id],
              notification_level: item[:notification_level],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
