# frozen_string_literal: true

module Migrations
  module Converters
    module Discourse
      class TopicUsers < Conversion::Step
        source do
          reads_table "topic_users", where: "user_id > 0"
          partition_by :topic_id
        end

        processor do
          def process(item)
            IntermediateDB::TopicUser.create(
              topic_id: item[:topic_id],
              user_id: item[:user_id],
              cleared_pinned_at: item[:cleared_pinned_at],
              first_visited_at: item[:first_visited_at],
              last_emailed_post_number: item[:last_emailed_post_number],
              last_posted_at: item[:last_posted_at],
              last_read_post_number: item[:last_read_post_number],
              last_visited_at: item[:last_visited_at],
              notification_level: item[:notification_level],
              notifications_changed_at: item[:notifications_changed_at],
              notifications_reason_id: item[:notifications_reason_id],
              total_msecs_viewed: item[:total_msecs_viewed],
            )
          end
        end
      end
    end
  end
end
