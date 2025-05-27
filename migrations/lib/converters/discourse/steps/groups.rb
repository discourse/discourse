# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Groups < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*) FROM groups
      SQL
    end

    def items
      @source_db.query <<~SQL
        SELECT g.*,
               u.id AS original_flair_upload_id,
               u.url AS flair_path,
               u.original_filename AS flair_filename,
               CASE WHEN g.automatic THEN g.name END AS existing_id
        FROM groups g
             LEFT JOIN uploads u ON g.flair_upload_id = u.id
      SQL
    end

    def process_item(item)
      flair_upload =
        if item[:original_flair_upload_id].present?
          IntermediateDB::Upload.create_for_file(
            path: item[:flair_path],
            filename: item[:flair_filename],
          )
        end

      IntermediateDB::Group.create(
        original_id: item[:id],
        allow_membership_requests: item[:allow_membership_requests],
        allow_unknown_sender_topic_replies: item[:allow_unknown_sender_topic_replies],
        automatic: item[:automatic],
        automatic_membership_email_domains: item[:automatic_membership_email_domains],
        bio_raw: item[:bio_raw],
        created_at: item[:created_at],
        default_notification_level: item[:default_notification_level],
        existing_id: item[:existing_id],
        flair_bg_color: item[:flair_bg_color],
        flair_color: item[:flair_color],
        flair_icon: item[:flair_icon],
        flair_upload_id: flair_upload&.id,
        full_name: item[:full_name],
        grant_trust_level: item[:grant_trust_level],
        members_visibility_level: item[:members_visibility_level],
        membership_request_template: item[:membership_request_template],
        mentionable_level: item[:mentionable_level],
        messageable_level: item[:messageable_level],
        name: item[:name],
        primary_group: item[:primary_group],
        public_admission: item[:public_admission],
        public_exit: item[:public_exit],
        title: item[:title],
        visibility_level: item[:visibility_level],
      )
    end
  end
end
