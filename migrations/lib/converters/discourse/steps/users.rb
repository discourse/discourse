# frozen_string_literal: true

module Migrations::Converters::Discourse
  class Users < ::Migrations::Converters::Base::ProgressStep
    attr_accessor :source_db

    def execute
      super

      @avatar_upload_creator = UploadCreator.new(column_prefix: "avatar", upload_type: "avatar")
    end

    def max_progress
      @source_db.count <<~SQL
        SELECT COUNT(*)
        FROM users
        WHERE id >= 0
      SQL
    end

    def items
      # TODO Discuss if we should have a DB migration to fix the duplicate user_avatars
      # instead of handling it here in the converter
      @source_db.query <<~SQL
        WITH latest_user_avatars AS (SELECT DISTINCT ON (user_id) *
                                     FROM user_avatars
                                     ORDER BY user_id, id DESC)
        SELECT u.*,
               up.url               AS avatar_url,
               up.original_filename AS avatar_filename,
               up.origin            AS avatar_origin,
               up.user_id           AS avatar_user_id,
               ua.custom_upload_id  AS avatar_custom_upload_id,
               ua.gravatar_upload_id
        FROM users u
             LEFT JOIN latest_user_avatars ua ON u.id = ua.user_id AND (ua.custom_upload_id = u.uploaded_avatar_id OR
                                                                        ua.gravatar_upload_id = u.uploaded_avatar_id)
             LEFT JOIN uploads up ON u.uploaded_avatar_id = up.id
        WHERE u.id > 0
        ORDER BY u.id
      SQL
    end

    def process_item(item)
      avatar_type =
        case item[:uploaded_avatar_id]
        when item[:avatar_custom_upload_id]
          1 # TODO Enum
        when item[:gravatar_upload_id]
          2 # TODO Enum
        end
      avatar_upload_id = @avatar_upload_creator.create_for(item) if avatar_type

      IntermediateDB::User.create(
        original_id: item[:id],
        active: item[:active],
        admin: item[:admin],
        approved: item[:approved],
        approved_at: item[:approved_at],
        approved_by_id: item[:approved_by_id],
        created_at: item[:created_at],
        date_of_birth: item[:date_of_birth],
        first_seen_at: item[:first_seen_at],
        flair_group_id: item[:flair_group_id],
        group_locked_trust_level: item[:group_locked_trust_level],
        ip_address: item[:ip_address],
        last_seen_at: item[:last_seen_at],
        locale: item[:locale],
        manual_locked_trust_level: item[:manual_locked_trust_level],
        moderator: item[:moderator],
        name: item[:name],
        primary_group_id: item[:primary_group_id],
        registration_ip_address: item[:registration_ip_address],
        silenced_till: item[:silenced_till],
        staged: item[:staged],
        title: item[:title],
        trust_level: item[:trust_level],
        uploaded_avatar_id: avatar_upload_id,
        avatar_type:,
        username: item[:username],
        views: item[:views],
      )
    end
  end
end
