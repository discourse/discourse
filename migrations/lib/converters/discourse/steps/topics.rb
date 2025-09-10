# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Topics < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM topics
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM topics
      SQL
    end

    def process_item(item)
      IntermediateDB::Topic.create(
        original_id: item[:id],
        archetype: item[:archetype],
        archived: item[:archived],
        bannered_until: item[:bannered_until],
        category_id: item[:category_id],
        closed: item[:closed],
        created_at: item[:created_at],
        deleted_at: item[:deleted_at],
        deleted_by_id: item[:deleted_by_id],
        external_id: item[:external_id],
        featured_link: item[:featured_link],
        pinned_at: item[:pinned_at],
        pinned_globally: item[:pinned_globally],
        pinned_until: item[:pinned_until],
        subtype: item[:subtype],
        title: item[:title],
        user_id: item[:user_id],
        views: item[:views],
        visibility_reason_id: item[:visibility_reason_id],
        visible: item[:visible],
      )
    end
  end
end
