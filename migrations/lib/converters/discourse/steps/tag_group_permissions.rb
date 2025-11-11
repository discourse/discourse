# frozen_string_literal: true

module Migrations::Converters::Discourse
  class TagGroupPermissions < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM tag_group_permissions
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT *
        FROM tag_group_permissions
        ORDER BY id
      SQL
    end

    def process_item(item)
      IntermediateDB::TagGroupPermission.create(
        group_id: item[:group_id],
        permission_type: item[:permission_type],
        tag_group_id: item[:tag_group_id],
        created_at: item[:created_at],
      )
    end
  end
end
