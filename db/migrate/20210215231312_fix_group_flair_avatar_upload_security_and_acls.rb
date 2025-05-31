# frozen_string_literal: true

class FixGroupFlairAvatarUploadSecurityAndAcls < ActiveRecord::Migration[6.0]
  disable_ddl_transaction!

  def up
    upload_ids = DB.query_single(<<~SQL)
      SELECT flair_upload_id
      FROM groups
      WHERE flair_upload_id IS NOT NULL
     SQL

    if upload_ids.any?
      reason = "group_flair fixup migration"
      DB.exec(<<~SQL, upload_ids: upload_ids, reason: reason, now: Time.zone.now)
        UPDATE uploads SET secure = false, security_last_changed_at = :now, updated_at = :now, security_last_changed_reason = :reason
        WHERE id IN (:upload_ids) AND uploads.secure
      SQL
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
