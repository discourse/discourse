# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserAvatars < ::Migrations::Importer::CopyStep
    depends_on :users

    requires_set :existing_user_ids, "SELECT DISTINCT user_id FROM user_avatars"

    column_names %i[
                   user_id
                   custom_upload_id
                   gravatar_upload_id
                   last_gravatar_download_attempt
                   created_at
                   updated_at
                 ]

    total_rows_query <<~SQL, MappingType::USERS, MappingType::UPLOADS
      SELECT COUNT(*)
      FROM users u
           JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?1
           JOIN mapped.ids mup ON u.uploaded_avatar_id = mup.original_id AND mup.type = ?2
    SQL

    rows_query <<~SQL, MappingType::USERS, MappingType::UPLOADS
      SELECT mu.discourse_id AS user_id, mup.discourse_id AS avatar_upload_id, u.avatar_type
      FROM users u
           JOIN mapped.ids mu ON u.original_id = mu.original_id AND mu.type = ?1
           JOIN mapped.ids mup ON u.uploaded_avatar_id = mup.original_id AND mup.type = ?2
      ORDER BY u.original_id
    SQL

    private

    def transform_row(row)
      return nil if @existing_user_ids.include?(row[:user_id])

      # TODO Enum
      case row[:avatar_type]
      when 1
        row[:custom_upload_id] = row[:avatar_upload_id]
      when 2
        row[:gravatar_upload_id] = row[:avatar_upload_id]
        row[:last_gravatar_download_attempt] = NOW
      end

      super
    end
  end
end
