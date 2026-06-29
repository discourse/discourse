# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TopicAllowedUsers < Conversion::Step
        source { reads_table "topic_allowed_users", where: "user_id > 0" }

        processor do
          def process(item)
            IntermediateDB::TopicAllowedUser.create(
              topic_id: item[:topic_id],
              user_id: item[:user_id],
              created_at: item[:created_at],
            )
          end
        end
      end
    end
  end
end
