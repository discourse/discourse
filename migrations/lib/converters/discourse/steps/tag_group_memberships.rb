# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TagGroupMemberships < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
         SELECT COUNT(*) FROM tag_group_memberships
       SQL
    end

    def items
      @source_db.query <<~SQL
          SELECT * FROM tag_group_memberships
          ORDER BY tag_group_id, tag_id
       SQL
    end

    def process_item(item)
      IntermediateDB::TagGroupMembership.create(
        created_at: item[:created_at],
        tag_group_id: item[:tag_group_id],
        tag_id: item[:tag_id],
      )
    end
  end
end
