module Jobs
  class FixOutOfSyncUserUploadedAvatar < Jobs::Onceoff
    def execute_onceoff(args)
      DB.exec(<<~SQL)
      WITH X AS (
        SELECT
          u.id AS user_id,
          ua.gravatar_upload_id AS gravatar_upload_id
        FROM users u
        JOIN user_avatars ua ON ua.user_id = u.id
        LEFT JOIN uploads ON uploads.id = u.uploaded_avatar_id
        WHERE u.uploaded_avatar_id IS NOT NULL
        AND uploads.id IS NULL
      )
      UPDATE users
      SET uploaded_avatar_id = X.gravatar_upload_id
      FROM X
      WHERE users.id = X.user_id
      AND coalesce(uploaded_avatar_id,-1) <> coalesce(X.gravatar_upload_id,-1)
      SQL
    end
  end
end
