# frozen_string_literal: true

module Migrations::Converters::Phpbb3
  class Categories < ::Migrations::Converters::Base::ProgressStep
    include SqlTransformer

    attr_accessor :source_db, :settings

    def max_progress
      count(<<~SQL, forum_type_link: Constants::FORUM_TYPE_LINK)
        SELECT COUNT(*)
        FROM phpbb_forums f
        WHERE f.forum_type <> :forum_type_link
      SQL
    end

    def items
      query(<<~SQL, forum_type_link: Constants::FORUM_TYPE_LINK)
        SELECT f.forum_id, f.parent_id, f.forum_name, f.forum_desc,
          f.left_id, x.first_post_time
        FROM phpbb_forums f
          LEFT OUTER JOIN (
            SELECT MIN(topic_time) AS first_post_time, forum_id
            FROM phpbb_topics
            GROUP BY forum_id
          ) x ON (f.forum_id = x.forum_id)
        WHERE f.forum_type <> :forum_type_link
        ORDER BY f.parent_id, f.left_id
      SQL
    end

    def process_item(item)
      parent_id = item[:parent_id]
      parent_id = nil if parent_id == 0

      created_at = item[:first_post_time] ? Time.at(item[:first_post_time]).utc : Time.now.utc

      IntermediateDB::Category.create(
        original_id: item[:forum_id],
        name: item[:forum_name],
        slug: slugify(item[:forum_name]),
        description: item[:forum_desc],
        parent_category_id: parent_id,
        position: item[:left_id] || 0,
        created_at:,
        user_id: -1,
      )
    end

    private

    def slugify(name)
      name.to_s.downcase.gsub(/[^a-z0-9]+/, "-").gsub(/^-|-$/, "")[0..49]
    end
  end
end
