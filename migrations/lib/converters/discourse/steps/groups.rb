# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Groups < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def execute
      super

      @flair_upload_creator = UploadCreator.new(column_prefix: "flair")
    end

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM groups
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT g.*,
               up.url               AS flair_url,
               up.original_filename AS flair_filename,
               up.origin            AS flair_origin,
               up.user_id           AS flair_user_id,
               CASE WHEN g.automatic THEN g.name END AS existing_id
        FROM groups g
             LEFT JOIN uploads up ON g.flair_upload_id = up.id
        ORDER BY g.id
      SQL
    end

    def process_item(item)
      IntermediateDB::Group.create(
        original_id: item[:id],
        allow_membership_requests: item[:allow_membership_requests],
        allow_unknown_sender_topic_replies: item[:allow_unknown_sender_topic_replies],
        automatic_membership_email_domains: item[:automatic_membership_email_domains],
        bio_raw: item[:bio_raw],
        created_at: item[:created_at],
        default_notification_level: item[:default_notification_level],
        existing_id: item[:existing_id],
        flair_bg_color: item[:flair_bg_color],
        flair_color: item[:flair_color],
        flair_icon: item[:flair_icon],
        flair_upload_id: @flair_upload_creator.create_for(item),
        full_name: item[:full_name],
        grant_trust_level: item[:grant_trust_level],
        members_visibility_level: item[:members_visibility_level],
        membership_request_template: item[:membership_request_template],
        mentionable_level: item[:mentionable_level],
        messageable_level: item[:messageable_level],
        name: item[:name],
        primary_group: item[:primary_group],
        public_admission: item[:public_admission],
        publish_read_state: item[:publish_read_state],
        public_exit: item[:public_exit],
        title: item[:title],
        visibility_level: item[:visibility_level],
      )
    end
  end
end
