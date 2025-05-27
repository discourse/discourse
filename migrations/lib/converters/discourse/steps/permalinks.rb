# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Permalinks < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM permalinks
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM permalinks
      SQL
    end

    def process_item(item)
      IntermediateDB::Permalink.create(
        url: item[:url],
        category_id: item[:category_id],
        external_url: item[:external_url],
        post_id: item[:post_id],
        tag_id: item[:tag_id],
        topic_id: item[:topic_id],
        user_id: item[:user_id],
      )
    end
  end
end
