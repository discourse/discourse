# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class Topics < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    run_in_parallel(true)

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL, topic_moved: Constants::TOPIC_MOVED)
        SELECT COUNT(*)
        FROM phpbb_topics t
        WHERE t.topic_status <> :topic_moved
      SQL
    end

    def items
      query(<<~SQL, topic_moved: Constants::TOPIC_MOVED)
        SELECT t.topic_id, t.forum_id, t.topic_title, t.topic_poster, t.topic_time,
          t.topic_views, t.topic_status, t.topic_type
        FROM phpbb_topics t
        WHERE t.topic_status <> :topic_moved
        ORDER BY t.topic_id
      SQL
    end

    def process_item(item)
      created_at = Time.at(item[:topic_time]).utc

      closed = item[:topic_status] == Constants::TOPIC_LOCKED
      pinned =
        item[:topic_type] == Constants::POST_STICKY || item[:topic_type] == Constants::POST_ANNOUNCE
      pinned_globally = item[:topic_type] == Constants::POST_GLOBAL

      IntermediateDB::Topic.create(
        original_id: item[:topic_id],
        title: item[:topic_title],
        category_id: item[:forum_id],
        user_id: item[:topic_poster],
        created_at:,
        views: item[:topic_views],
        closed:,
        pinned_at: pinned || pinned_globally ? created_at : nil,
        pinned_globally:,
        visible: true,
        archetype: "regular",
      )
    end
  end
end
