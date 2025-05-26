# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Badges < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM badges
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT * FROM badges
      SQL
    end

    def process_item(item)
      item[:existing_id] = item[:name].split.map(&:capitalize).join if item[:system]

      IntermediateDB::Badge.create(
        original_id: item[:id],
        name: item[:name],
        description: item[:description],
        badge_type_id: item[:badge_type_id],
        created_at: item[:created_at],
        allow_title: item[:allow_title],
        multiple_grant: item[:multiple_grant],
        icon: item[:icon],
        listable: item[:listable],
        target_posts: item[:target_posts],
        query: item[:query],
        enabled: item[:enabled],
        existing_id: item[:existing_id],
        auto_revoke: item[:auto_revoke],
        badge_grouping_id: item[:badge_grouping_id],
        trigger: item[:trigger],
        show_posts: item[:show_posts],
        system: item[:system],
        long_description: item[:long_description],
        image_upload_id: item[:image_upload_id],
        show_in_post_header: item[:show_in_post_header],
      )
    end
  end
end
