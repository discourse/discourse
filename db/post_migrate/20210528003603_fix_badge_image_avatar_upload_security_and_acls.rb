# frozen_string_literal: true

class FixBadgeImageAvatarUploadSecurityAndAcls < ActiveRecord::Migration[6.1]
  disable_ddl_transaction!

  def up
    upload_ids = DB.query_single(<<~SQL
      SELECT image_upload_id
      FROM badges
      INNER JOIN uploads ON uploads.id = badges.image_upload_id
      WHERE image_upload_id IS NOT NULL AND uploads.secure
     SQL
    )

    if upload_ids.any?
      reason = "badge_image fixup migration"
      DB.exec(<<~SQL, upload_ids: upload_ids, reason: reason, now: Time.zone.now)
        UPDATE uploads SET secure = false, security_last_changed_at = :now, updated_at = :now, security_last_changed_reason = :reason
        WHERE id IN (:upload_ids)
      SQL

      if Discourse.store.external?
        uploads = Upload.where(id: upload_ids)
        uploads.each do |upload|
          Discourse.store.update_upload_ACL(upload)
          upload.touch
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
