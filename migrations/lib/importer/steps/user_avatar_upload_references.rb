# frozen_string_literal: true

module Migrations::Importer::Steps
  class UserAvatarUploadReferences < ::Migrations::Importer::Step
    depends_on :user_avatars

    def execute
      super

      update_uploaded_avatar_id
      insert_custom_avatar_upload_references
      insert_gravatar_upload_references
    end

    private

    def update_uploaded_avatar_id
      DB.exec(<<~SQL)
        UPDATE users u
        SET uploaded_avatar_id = COALESCE(ua.custom_upload_id, ua.gravatar_upload_id)
        FROM user_avatars ua
        WHERE u.id = ua.user_id
          AND u.uploaded_avatar_id IS NULL
          AND (ua.custom_upload_id IS NOT NULL OR ua.gravatar_upload_id IS NOT NULL)
      SQL
    end

    def insert_custom_avatar_upload_references
      DB.exec(<<~SQL)
        INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
        SELECT ua.custom_upload_id, 'UserAvatar', ua.id, ua.created_at, ua.updated_at
        FROM user_avatars ua
        WHERE ua.custom_upload_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
    end

    def insert_gravatar_upload_references
      DB.exec(<<~SQL)
        INSERT INTO upload_references (upload_id, target_type, target_id, created_at, updated_at)
        SELECT ua.gravatar_upload_id, 'UserAvatar', ua.id, ua.created_at, ua.updated_at
        FROM user_avatars ua
        WHERE ua.gravatar_upload_id IS NOT NULL
        ON CONFLICT DO NOTHING
      SQL
    end
  end
end
